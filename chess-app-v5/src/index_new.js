import { Chess } from 'chess.js';
import jwt from 'jsonwebtoken';
import { generate } from "random-words";
import { DurableObject } from 'cloudflare:workers';

const BASE_URL = "chess-app-v5.concannon-e.workers.dev";
const STOCKFISH_URL = "https://stockfish.online/api/s/v2.php";
const SECRET_KEY = "capstone-chesslink"
const OPTIONS = { expiresIn: 60*30 };

// Standardized Response Helper
function createResponse(body, status = 200) {
    return new Response(JSON.stringify(body), {
        status,
        headers: { "Content-Type": "application/json" }
    });
}

// Utility function to safely parse CSV strings into an array
function parseCSV(csvString) {
    return csvString ? csvString.split(',').filter(Boolean) : [];
}

// Utility function to convert an array into a CSV string
function toCSV(array) {
    return array.length > 0 ? array.join(',') : null;
}


function standardGameInfo(game, playerID, players_color, players, message_type = "game-state") {
    const color = (players_color.white === playerID) ? "white" : "black";
    
    return {
        fen: game.fen(),
        color,
        turn: game.turn(),
        game_over: game.isGameOver(),
        checkmate: game.isCheckmate(),
        players,
        message_type
    };
}


function generateToken(playerID) {
    const payload = { playerID: playerID, role: "user" };
    return jwt.sign(payload, SECRET_KEY, OPTIONS);
}


function verifyToken(request) {
    try {
        const token = request.headers.get('authorization');
        jwt.verify(token, SECRET_KEY, OPTIONS); // This will throw an error if the token is invalid
        return true; // Token is valid
    } catch (err) {
        return false; // Token is invalid
    }
}
  


export class ChessGame extends DurableObject {
    constructor(ctx, env) {
        super(ctx, env);
        console.log("New Durable Object instance created");
        this.storage = ctx.storage;
        this.game = null;
        this.players = new Set();
        this.players_color = { white: null, black: null };
        this.gameID = null;
        this.depth = 10;
        this.ai = false;
        this.lastMove = "";
        this.initializeGameState();
    }

    async initializeGameState() {
        const [storedState, storedPlayers, storedPlayersColor, storedAi, storedDepth, storedGameID, storedMove] = await Promise.all([
            this.storage.get("gameState"),
            this.storage.get("players"),
            this.storage.get("players_color"),
            this.storage.get("ai"),
            this.storage.get("depth"),
            this.storage.get("gameID"),
            this.storage.get("lastMove")
        ]);

        this.game = storedState ? new Chess(storedState) : new Chess();
        this.players_color = storedPlayersColor || { white: null, black: null };
        this.players = new Set(storedPlayers || []);
        this.ai = storedAi || false;
        this.depth = storedDepth || 10;
        this.gameID = storedGameID || null;
        this.lastMove = storedMove || null;
        console.log("initializing game state ai: " + this.ai.toString() + " players: " + Array.from(this.players).join(", ") + " colors: " + JSON.stringify(this.players_color));
    }

    async fetch(request) {
        const url = new URL(request.url);
        const playerID = url.searchParams.get("playerID");
        
        if (!this.gameID) {
            this.gameID = url.searchParams.get("gameID");
            this.storage.put("gameID", this.gameID);
        }

        if (url.pathname === "/connect" && request.headers.get("Upgrade") === "websocket") {
            return this.handleWebSocket(request);
        }

        switch (url.pathname) {
            case "/join-game":
                const ai = url.searchParams.get("ai")?.toLowerCase() === "true";
                const depth = parseInt(url.searchParams.get("depth"), 10);
                return this.handleJoinGame(playerID, ai, depth);
            case "/game-info":
                return createResponse(standardGameInfo(this.game, playerID, this.players_color, Array.from(this.players).join(", ")));
            case "/update-game-info":
                return this.handleUpdateGame(request);
            default:
                return createResponse({ error: "Not Found" }, 404);
        }
    }

    async handleJoinGame(playerID, ai, depth = 10) {
        if (!playerID) return createResponse({message_type: "error", error: "Player ID required" }, 400);
        
        // try {
            console.log("Current players: ", JSON.stringify(Array.from(this.players)));
            if (!this.players.has(playerID)) {
                if (this.players.length >= 2) {
                    return createResponse({message_type: "error", error: "Game is full. Cannot join." }, 403);
                }
                this.players.add(playerID);
                if (ai && this.players.size === 1) {
                    console.log("Entered here: " + ai.toString());
                    this.players.add("AI");
                    this.#updateGamePlayersInDB();
                    await this.storage.put("ai", true);
                    await this.storage.put("depth", depth);
                    this.ai = true;
                }
                else {
                    this.players_color.white = playerID;
                    await this.storage.put("players_color", this.players_color);
                    await this.storage.put("ai", false);
                }
                await this.storage.put("players", Array.from(this.players));

                console.log("Entered players: " + Array.from(this.players).toString());
                return createResponse({gameID: this.gameID});
            }
            else {
                return createResponse({message_type: "error", error: "You are already in this game!" }, 403);
            }

            if (this.players.size === 2) {
                this.players_color = this.#determinePlayerColors(playerID);
                await this.#updateGamePlayersInDB();
                await this.storage.put("players_color", this.players_color);
            }
            if (this.lastMove){
                return createResponse({...standardGameInfo(this.game, playerID, this.players_color, Array.from(this.players).join(", ")), lastMove: this.lastMove});
            }
            else
                return createResponse(standardGameInfo(this.game, playerID, this.players_color, Array.from(this.players).join(", ")));
        // } catch (error) {
            // console.log("Error happened: ", error);
            // return createResponse({message_type: "error", error: "Error updating durable object storage." }, 500);
        // }

    }


    async handleUpdateGame(request) {
        try {
            const data = await request.json();

            if (data.message_type === "player-leaving") {
                const playerID = data.playerLeaving;

                if (!this.players.has(playerID)) {
                    return new Response(JSON.stringify({ success: false, message: "Player not in game." }), { status: 400 });
                }

                // // Remove the player from the game state
                // this.players.delete(playerID);

                // Broadcast the update to all remaining players
                const message = {
                    message_type: "player-left",
                    playerLeaving: playerID,
                };

                await this.sendToOpponent(message);
                await this.handleGameOver();

                return new Response(JSON.stringify({ success: true, message: "Player removed from game." }));
            }

            return new Response(JSON.stringify({ success: false, message: "Invalid message type." }), { status: 400 });
        } catch (error) {
            console.error("Error handling game update:", error);
            return new Response(JSON.stringify({ error: "Failed to update game." }), { status: 500 });
        }
    }

    async #updateGamePlayersInDB() {
        try {
            await this.env.DB.prepare(`
                UPDATE games 
                SET player_white = ?, player_black = ?
                WHERE id = ?
            `).bind(
                this.players_color.white,
                this.players_color.black,
                this.gameID
            ).run();
        } catch (error) {
            console.error("Player update failed:", error);
        }
    }
    
    // Determine player color through coin flip
    #determinePlayerColors(newPlayerID) {        
        // Coin flip for second player
        const shouldSwap = Math.random() < 0.5;
        const existingPlayer = this.players_color.white;
        
        return shouldSwap ? 
            { white: newPlayerID, black: existingPlayer } :
            { white: existingPlayer, black: newPlayerID };
    }

    async #updateMovesInDB(moveSan) {
        try {
            const result = await this.env.DB.prepare(`
                SELECT moves 
                FROM games 
                WHERE id = ?
            `).bind(this.gameID).first();
            
            const existingMoves = result && result.moves ? parseCSV(result.moves) : [];
            existingMoves.push(moveSan);
            const newMoves = toCSV(existingMoves);

            await this.env.DB.prepare(`
                UPDATE games
                SET moves = ?
                WHERE id = ?
            `).bind(newMoves, this.gameID).run();
        } catch (error) {
            console.error("Error updating moves in DB:", error);
        }
    }

    async #finalizeGameInDB() {
        const winner = this.game.isCheckmate() ? 
            (this.game.turn() === 'w' ? this.players_color.black : this.players_color.white) :
            null;

        try {
            await this.env.DB.prepare(`
                UPDATE games 
                SET winner = ?, 
                    status = ?, 
                    ended_at = CURRENT_TIMESTAMP
                WHERE id = ?
            `).bind(
                winner,
                this.game.isGameOver() ? 
                    (this.game.isCheckmate() ? 'checkmate' : 'draw') : 'active',
                this.gameID
            ).run();
        } catch (error) {
            console.error("Game finalization failed:", error);
        }
    }

    async #updatePlayerStats() {
        try {
            const { results } = await this.env.DB.prepare(`
                SELECT moves, player_white, player_black, winner
                FROM games WHERE id = ?
            `).bind(this.gameID).all();

            if (!results || results.length === 0) {
                console.error("Game not found for stats update:", this.gameID);
                return;
            }

            const game = results[0];
            const movesArray = parseCSV(game.moves);
            const totalMoves = movesArray.length;

            const players = [game.player_white, game.player_black]
                .filter(p => p && p !== "AI");

            for (const playerID of players) {
                const isWinner = playerID === game.winner;
                const isDraw = !game.winner;

                // First update games_played, wins, losses, and ties
                await this.env.DB.prepare(`
                    UPDATE users SET
                        games_played = games_played + 1,
                        wins = wins + ?,
                        losses = losses + ?,
                        ties = ties + ?
                    WHERE id = ?
                `).bind(
                    isWinner ? 1 : 0,
                    !isWinner && !isDraw ? 1 : 0,
                    isDraw ? 1 : 0,
                    playerID
                ).run();

                // Then update moves_per_game using the new value of games_played
                await this.env.DB.prepare(`
                    UPDATE users SET
                        moves_per_game = FLOOR(((moves_per_game * (games_played - 1)) + ?) / games_played)
                    WHERE id = ?
                `).bind(
                    totalMoves,
                    playerID
                ).run();
            }
        } catch (error) {
            console.error("Stats update failed:", error);
        }
    }


    async handleWebSocket(request) {
        const url = new URL(request.url);
        const playerID = url.searchParams.get("playerID");

        // const joinGameResponse = this.handleJoinGame(playerID, this.ai, this.depth);
        // if (joinGameResponse.message_type === "error") {
        //     return joinGameResponse
        // }

        const [clientSocket, serverSocket] = new WebSocketPair();
        this.ctx.acceptWebSocket(serverSocket);

        // Attach playerID to WebSocket for identification
        serverSocket.serializeAttachment({ playerID });

        // Assign players to sides if not already assigned
        if (!this.players_color.white) {
            this.players_color.white = playerID;
        } else if (!this.players_color.black && this.players_color.white !== playerID) {
            this.players_color.black = playerID;
        }

        await this.storage.put("players_color", this.players_color);
        await serverSocket.send(JSON.stringify(standardGameInfo(this.game, playerID, this.players_color, Array.from(this.players).join(", "))));

        return new Response(null, { status: 101, webSocket: clientSocket });
    }

    // Handle incoming WebSocket messages
    async webSocketMessage(ws, msg) {
        const data = JSON.parse(msg);
        if (data.message_type === "move") {
            await this.processMove(ws, data);
        }
        else if (data.message_type === "player_message") {
            // Intended to handle user sending emojis / text messages to the opponent
            await this.processPlayerMessage(ws, data);
        }
    }

    async processMove(ws, data) {
        const { playerID, move } = data;
        const isWhiteTurn = this.game.turn() === 'w';
        const isPlayerWhite = this.players_color.white === playerID;
        const isValidTurn = (isWhiteTurn && isPlayerWhite) || (!isWhiteTurn && !isPlayerWhite);

        if (!isValidTurn) {
            ws.send(JSON.stringify(createResponse({ message_type: "error", error: "Not your turn" }, 403)));
            return;
        }

        let result;
        try {
            result = this.game.move(move);
        } catch {
            result = null;
        }

        if (result) {
            await this.storage.put("gameState", this.game.fen());
            await this.storage.put("lastMove", JSON.stringify(move.from + move.to));
            await this.#updateMovesInDB(result.san); // Modified: Save move to DB

            const confirmationPayload = JSON.stringify(standardGameInfo(this.game, playerID, this.players_color, this.players, "confirmation"));
            ws.send(confirmationPayload);
            console.log("Process move: " + this.ai.toString());
            if (this.ai) {
                // Get AI move from Stockfish
                await this.handleAIMove(ws, playerID);
            } else {
                this.broadcastMove(ws, result, playerID);
            }
        } else {
            ws.send(JSON.stringify(createResponse({ message_type: "error", error: "Invalid move" }, 400)));
        }

        if (this.game.isGameOver()) {
            await this.#finalizeGameInDB();
            await this.#updatePlayerStats(); 
        }
    }
    

    async processPlayerMessage(ws, data) {
        this.sendToOpponent(ws, data);
        return
    }


    async getAIMove(fen, depth=4) {
    
        // Validate depth to ensure it meets the API requirement
        if (depth >= 16 || depth <= 0) {
            throw new Error("Depth must be an integer between 1 and 15.");
        }
    
        // Build the request URL with query parameters
        const url = new URL(STOCKFISH_URL);
        url.searchParams.append("fen", fen);
        url.searchParams.append("depth", depth);
    
        try {
            const response = await fetch(url.toString());    
            if (!response.ok) {
                throw new Error(`API Error: ${response.statusText}`);
            }
            const data = await response.json();
            return data.bestmove || "No move found.";
        } catch (error) {
            console.error("Error fetching AI move:", error.message);
            throw error;
        }
    }

    // Needs more error handling
    async handleAIMove(ws, playerID) {
        const aiMove = await this.getAIMove(this.game.fen(), this.depth);
        console.log("AI Move: " + JSON.stringify(aiMove));

        if (aiMove) {
            const result = this.game.move(aiMove);
            await this.storage.put("gameState", this.game.fen());
            await this.storage.put("lastMove", JSON.stringify(aiMove.from + aiMove.to));

            const aiMovePayload = JSON.stringify(
                standardGameInfo(this.game, playerID, this.players_color, Array.from(this.players).join(", "), "move")
            );
            ws.send(aiMovePayload);
            await this.#updateMovesInDB(result.san); // Update db after sending move
        } else {
            ws.send(JSON.stringify(createResponse({ message_type: "error", error: "AI move failed" }, 500)));
        }
    } 
    
    async getWebSocketFromPlayerID(playerID) {
        const playerSocket = this.ctx.getWebSockets().find((ws) => {
            const attachment = ws.serialized; // Extract serialized attachment
            return attachment && attachment.playerID === playerID;
        });
    
        if (playerSocket) {
            return playerSocket;
        } else {
            console.log(`No active WebSocket connection found for playerID: ${playerID}`);
            return null;
        }
    }

    // Function to generate the payload to be sent to the opponent
    generateMovePayload(game, senderID, playersColor, players, moveResult) {
        return JSON.stringify({
            ...standardGameInfo(game, senderID, playersColor, players, "move"),
            move: { from: moveResult["from"], to: moveResult["to"] },
        });
    }


    // Function to send the payload to the opposing WebSocket
    async sendToOpponent(senderSocket, payload) {
        const allSockets = this.ctx.getWebSockets();
    
        allSockets.forEach((ws) => {
            if (ws !== senderSocket && ws.readyState === ws.OPEN) {
                ws.send(payload);
            }
        });
    }


    // Broadcast message to the opponent only
    async broadcastMove(ws, moveResult, senderID) {
        const payload = this.generateMovePayload(this.game, senderID, this.players_color, Array.from(this.players).join(", "), moveResult);
        await this.sendToOpponent(ws, payload);
    }


    // Handle WebSocket closure
    webSocketClose(ws) {
        const { playerID } = ws.deserializeAttachment();
        console.log(`WebSocket closed for player: ${playerID}`);
    }

    // Handle WebSocket errors
    webSocketError(ws) {
        const { playerID } = ws.deserializeAttachment();
        console.error(`WebSocket error for player: ${playerID}`);
    }
}







export default {
    async fetch(request, env) {
        const url = new URL(request.url);
        const playerID = url.searchParams.get("playerID");
        const { GAME_ROOM, DB } = env;

        const url_path = url.pathname.toLowerCase().split('/');
        console.log(url_path.toString());  
        
        switch (url_path[1]) {
            case "create":
                return handleGameCreation(playerID, url, request, GAME_ROOM, DB);
            case "player":
                return handlePlayerActions(url_path, url, request, playerID, DB, GAME_ROOM);
            case "connect":
                return handleConnect(url, request, GAME_ROOM);
            case "replay":
                return handleReplayGame(request, url, DB);
            default:
                return createResponse({message_type: "error", error: "Not Found" }, 404);
        }
    }
};

async function handleGameCreation(playerID, url, request, GAME_ROOM, DB, origin = 1) {
    if (!playerID) return createResponse({message_type: "error", error: "Player ID required." }, 400);
    if (!verifyToken(request) && origin) return createResponse({message_type: "error", error: "Authentication Failed" }, 403);

    const max = 999999999;
    const min = 0;
    const gameString = generate(3).join("-") + String(Math.floor(Math.random() * (max - min) + min));
    const gameRoomID = GAME_ROOM.idFromName(gameString);
    const gameRoom = GAME_ROOM.get(gameRoomID);
    const success = await insertNewGame(playerID, gameString, DB);
    let ai = false;
    ai = url.searchParams.get("ai")?.toLowerCase() === "true";
    const durable_url = new URL("/join-game", url.origin);
    durable_url.searchParams.append("playerID", playerID);
    durable_url.searchParams.append("ai", ai);
    durable_url.searchParams.append("depth", url.searchParams.get("depth"));
    

    await DB.prepare(`
        INSERT INTO games (id, player_white, status)
        VALUES (?, ?, 'pending')
    `).bind(gameString, playerID).run();

    await gameRoom.fetch(durable_url);

   
    if (success) {
        return createResponse({ gameID: gameString });
    } else {
        return createResponse({message_type: "error", error: "Database error occurred." }, 500);
    }
}


async function handleConnect(url, request, GAME_ROOM) {
    const gameID = GAME_ROOM.idFromName(url.searchParams.get("gameID"));
    const playerID = url.searchParams.get("playerID");

    if (!gameID || !playerID) {
        return new Response("Missing gameID or playerID", { status: 400 });
    }

    // Retrieve the existing game Durable Object by ID
    const gameRoom = GAME_ROOM.get(gameID);

    return gameRoom.fetch(request);
}



// Get game replay data
async function handleReplayGame(request, url, DB) {
    if (!verifyToken(request)) return createResponse({message_type: "error", error: "Authentication Failed" }, 403);

    try {
        const gameID = url.searchParams.get("gameID");
        const { results } = await DB.prepare(`
            SELECT moves FROM games
            WHERE id = ?
        `).bind(gameID).all();

        if (results && results.length > 0 && results[0].moves) {
            const moves = parseCSV(results[0].moves);
            return createResponse({ moves }); 
        } else {
            return createResponse({ moves });
        }
    } catch (error) {
        console.error("Replay error:", error);
        return createResponse({ error: "Failed to get replay" }, 500);
    }
}


async function handlePlayerActions(url_path, url, request, playerID, DB, GAME_ROOM) {
    switch (url_path[2]) {
        case "login":
            return loginPlayer(playerID, url, DB);
        case "join-game":
            return joinGame(playerID, url, request, GAME_ROOM, DB);
        case "games":
            return getGameInfo(playerID, request, GAME_ROOM, DB);
        case "register":
            return registerPlayer(playerID, url, DB);
        case "end-game":
            return removeGameFromActive(playerID, url, request, DB, GAME_ROOM);
        case "end-all-games":
            return removeAllGames(playerID, request, DB, GAME_ROOM);
        case "friends":
            return getFriends(playerID, DB);
        case "see-friend-requests":
            return seeFriendRequests(playerID, DB);
        case "send-friend-request":
            return sendFriendRequest(playerID, url, DB);
        case "accept-friend-request":
            return acceptFriendRequest(playerID, url, DB);
        case "challenge-friend":
            return challengeFriend(playerID, url, DB);
        case "accept-challenge":
            return acceptChallenge(playerID, url, DB, GAME_ROOM);
        case "see-challenge-requests":
            return seeChallengeRequests(playerID, DB);
        case "game":
            return getGameData(playerID, url, request, DB);
        case "stats":
            return getPlayerStats(playerID, DB);
        default:
            return createResponse({message_type: "error", error: "Invalid action" }, 400);
    }
}


async function loginPlayer(playerID, url, DB) {
    const password = url.searchParams.get("password");
    const query = `SELECT * FROM users WHERE id = ? AND password = ?;`;

    const result = await DB.prepare(query).bind(playerID, password).first();
    const token = generateToken(playerID);
    if (result) {
        return createResponse({token: token});
    } else {
        return createResponse({}, 404);
    }
}


async function joinGame(playerID, url, request, GAME_ROOM, DB, origin = 1, gameID = null) {
    if (origin && !verifyToken(request)) return createResponse({message_type: "error", error: "Authentication Failed" }, 403);

    if (origin) gameID = url.searchParams.get("gameID");

    const gameRoom = GAME_ROOM.get(GAME_ROOM.idFromName(gameID));
    const response = await gameRoom.fetch(
        new URL("/join-game?playerID=" + playerID + "&ai=false", url.origin)
    );
    console.log("Response" , JSON.stringify(response));

    if (response.ok) {
        const clonedResponse = response.clone(); // Clone before consuming
        const data = await clonedResponse.json();
        if (data.message_type !== "error") {
            await insertNewGame(playerID, gameID, DB);
        }
    }
    return response;
}


async function insertNewGame(playerID, gameID, DB) {
    try {
        // Fetch current active games
        const query = `SELECT active_games FROM users WHERE id = ?`;
        const result = await DB.prepare(query).bind(playerID).first();
        let activeGames = parseCSV(result?.active_games);

        // Prevent duplicate game entries
        if (activeGames.includes(gameID)) {
            return createResponse({ success: false, message: "Game already exists in active games." }, 400);
        }

        // Add new game to list
        activeGames.push(gameID);

        // Update the database
        const updateQuery = `UPDATE users SET active_games = ? WHERE id = ?`;
        await DB.prepare(updateQuery).bind(toCSV(activeGames), playerID).run();

        return createResponse({ success: true, message: "Game added to active games." });
    } catch (error) {
        console.error("Error inserting new game:", error);
        return createResponse({ error: "Failed to insert new game." }, 500);
    }
}


async function removeGameFromActive(playerID, url, request, DB, GAME_ROOM) {
    if (!verifyToken(request)) 
        return createResponse({ message_type: "error", error: "Authentication Failed" }, 403);

    const gameID = url.searchParams.get("gameID");
    if (!gameID) 
        return createResponse({ message_type: "error", error: "Missing gameID parameter" }, 400);

    try {
        // Step 1: Fetch current active games
        const query = `SELECT active_games FROM users WHERE id = ?`;
        const result = await DB.prepare(query).bind(playerID).first();
        console.log("result" + JSON.stringify(result));
        let activeGames = parseCSV(result?.results[0]?.active_games);
        console.log("activeGames"+ activeGames.toString());

        // Step 2: Check if the game exists in the list
        if (!activeGames.includes(gameID)) {
            return createResponse({ success: false, message: "Game not found in active games." }, 404);
        }

        // Step 3: Remove the game from the list
        activeGames = activeGames.filter(id => id !== gameID);
        const updatedGames = toCSV(activeGames); // Convert back to CSV string

        // Step 4: Update the database
        const updateQuery = `UPDATE users SET active_games = ? WHERE id = ?`;
        await DB.prepare(updateQuery).bind(updatedGames, playerID).run();

        // Step 5: Notify the Durable Object about player leaving
        const gameRoomId = GAME_ROOM.idFromName(gameID);
        const gameRoom = GAME_ROOM.get(gameRoomId);

        try {
            const response = await gameRoom.fetch("https://" + BASE_URL + "/update-game-info", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    playerLeaving: playerID,
                }),
            });

            if (!response.ok) {
                console.error(`Failed to update game status for gameID: ${gameID}`);
            }
        } catch (error) {
            console.error(`Error communicating with Durable Object for gameID: ${gameID}`, error);
        }

        return createResponse({ success: true, message: "Game removed from active games." });
    } catch (error) {
        console.error("Error removing game from active games:", error);
        return createResponse({ error: "Failed to remove game." }, 500);
    }
}


async function removeAllGames(playerID, request, DB, GAME_ROOM) {
    if (!verifyToken(request)) 
        return createResponse({ message_type: "error", error: "Authentication Failed" }, 403);

    try {
        // Step 1: Fetch all active games for the player
        const query = `SELECT active_games FROM users WHERE id = ?`;
        const result = await DB.prepare(query).bind(playerID).first();
        let activeGames = parseCSV(result?.active_games);

        if (activeGames.length === 0) {
            console.log(`No active games found for player: ${playerID}`);
            return createResponse({ success: true, message: "No active games to remove." });
        }

        // Step 2: Notify each game’s Durable Object
        for (const gameID of activeGames) {
            const gameRoomId = GAME_ROOM.idFromName(gameID);
            const gameRoom = GAME_ROOM.get(gameRoomId);

            try {
                const response = await gameRoom.fetch("https://" + BASE_URL + "/update-game-info", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({
                        playerLeaving: playerID,
                    }),
                });

                if (!response.ok) {
                    console.error(`Failed to update game status for gameID: ${gameID}`);
                }
            } catch (error) {
                console.error(`Error communicating with Durable Object for gameID: ${gameID}`, error);
            }
        }

        // Step 3: Remove all active games for the player in the database
        const updateQuery = `UPDATE users SET active_games = NULL WHERE id = ?`;
        await DB.prepare(updateQuery).bind(playerID).run();

        return createResponse({ success: true, message: "All active games removed." });
    } catch (error) {
        console.error("Error removing all active games:", error);
        return createResponse({ error: "Failed to remove all games." }, 500);
    }
}


async function getGameInfo(playerID, request, GAME_ROOM, DB) {
    if (!playerID) return createResponse({message_type: "error", error: "Player ID is required." }, 400);
    if (!verifyToken(request)) return createResponse({message_type: "error", error: "Authentication Failed" }, 403);

    const query = `SELECT active_games FROM users WHERE id = ?;`;
    const result = await DB.prepare(query).bind(playerID).all();

    if (result.success && result.results.length === 0) {
        return createResponse({ games: [] });
    }

    const activeGames = String(result.results[0].active_games);

    if (activeGames === "null") {
        return createResponse({ games: [] });
    }

    const gameIDs = activeGames ? activeGames.split(',') : [];

    const gamesInfo = await Promise.all(
        gameIDs.map(async (gameID) => {
            const gameRoom = GAME_ROOM.get(GAME_ROOM.idFromName(gameID));
            const response = await gameRoom.fetch("https://" + BASE_URL + "/game-info");
            const data = await response.json();
            return { gameID, players: data.players, turn: data.turn };
        })
    );

    return createResponse({ games: gamesInfo });
}


async function registerPlayer(playerID, url, DB) {
    const password = url.searchParams.get("password");
    const email = url.searchParams.get("email");

    if (!password || !email || !playerID) {
        return createResponse({
            error: "Missing required fields (playerID, email, or password)",
            message_type: "error"
        }, 400);
    }

    const query = `INSERT INTO users (id, password, email) VALUES (?, ?, ?);`;
    try {
        const result = await DB.prepare(query).bind(playerID, password, email).run();
        if (result.success) {
            return createResponse({
                message: "User registered successfully.",
                message_type: "confirmation"
            });
        } else {
            return createResponse({
                error: "Failed to register user.",
                message_type: "error"
            }, 500);
        }
    } catch (error) {
        if (error.message.includes("UNIQUE constraint failed") || error.message.includes("already exists")) {
            return createResponse({
                error: "PlayerID already taken. Please choose another.",
                message_type: "error"
            }, 400);
        }
        return createResponse({
            error: "Error registering user. Please try again later.",
            message_type: "error"
        }, 500);
    }
}

// Retrieve list of friends
async function getFriends(playerID, DB) {
    const query = `SELECT friends FROM users WHERE id = ?`;
    try {
        const result = await DB.prepare(query).bind(playerID).first();
        return createResponse({ friends: parseCSV(result?.friends) });
    } catch (error) {
        console.error("Error retrieving friends:", error);
        return createResponse({ error: "Failed to retrieve friends" }, 500);
    }
}

// Retrieve both incoming and outgoing friend requests
async function seeFriendRequests(playerID, DB) {
    const query = `SELECT incoming_requests, outgoing_requests FROM users WHERE id = ?`;
    try {
        const result = await DB.prepare(query).bind(playerID).first();
        return createResponse({
            incoming_requests: parseCSV(result?.incoming_requests),
            outgoing_requests: parseCSV(result?.outgoing_requests)
        });
    } catch (error) {
        console.error("Error retrieving friend requests:", error);
        return createResponse({ error: "Failed to retrieve friend requests" }, 500);
    }
}

// Retrieve both incoming and outgoing friend requests
async function seeChallengeRequests(playerID, DB) {
    const query = `SELECT incoming_challenges, outgoing_challenges FROM users WHERE id = ?`;
    try {
        const result = await DB.prepare(query).bind(playerID).first();
        return createResponse({
            incoming_challenges: parseCSV(result?.incoming_challenges),
            outgoing_challenges: parseCSV(result?.outgoing_challenges)
        });
    } catch (error) {
        console.error("Error retrieving friend requests:", error);
        return createResponse({ error: "Failed to retrieve friend requests" }, 500);
    }
}

// Send a friend request
async function sendFriendRequest(playerID, url, DB) {
    const friendID = url.searchParams.get("friendID");
    if (!playerID || !friendID) {return createResponse({ error: "Missing playerID or friendID" }, 400);}
    if (playerID === friendID) {return createResponse({ error: "Cannot send friend request to yourself" }, 400);}

    try {
        // Fetch outgoing requests for sender
        let query = `SELECT outgoing_requests FROM users WHERE id = ?`;
        let sender = await DB.prepare(query).bind(playerID).first();
        let outgoingRequests = parseCSV(sender?.outgoing_requests);

        // Fetch incoming requests for receiver
        query = `SELECT incoming_requests FROM users WHERE id = ?`;
        let receiver = await DB.prepare(query).bind(friendID).first();
        let incomingRequests = parseCSV(receiver?.incoming_requests);

        // Prevent duplicate requests
        if (outgoingRequests.includes(friendID) || incomingRequests.includes(playerID)) {
            return createResponse({ success: false, message: "Friend request already sent or received." }, 400);
        }

        outgoingRequests.push(friendID);
        incomingRequests.push(playerID);

        // Update sender's outgoing requests
        query = `UPDATE users SET outgoing_requests = ? WHERE id = ?`;
        await DB.prepare(query).bind(toCSV(outgoingRequests), playerID).run();

        // Update receiver's incoming requests
        query = `UPDATE users SET incoming_requests = ? WHERE id = ?`;
        await DB.prepare(query).bind(toCSV(incomingRequests), friendID).run();

        return createResponse({ success: true, message: "Friend request sent." });
    } catch (error) {
        console.error("Error sending friend request:", error);
        return createResponse({ error: "Failed to send friend request" }, 500);
    }
}

// Accept a friend request
async function acceptFriendRequest(playerID, friendID, DB) {
    try {
        // Fetch incoming requests and friends for accepting player
        let query = `SELECT incoming_requests, friends FROM users WHERE id = ?`;
        let player = await DB.prepare(query).bind(playerID).first();
        let incomingRequests = parseCSV(player?.incoming_requests);
        let friends = parseCSV(player?.friends);

        // Fetch outgoing requests and friends for sender
        query = `SELECT outgoing_requests, friends FROM users WHERE id = ?`;
        let friend = await DB.prepare(query).bind(friendID).first();
        let outgoingRequests = parseCSV(friend?.outgoing_requests);
        let friendFriends = parseCSV(friend?.friends);

        // Verify request exists
        if (!incomingRequests.includes(friendID)) {
            return createResponse({ success: false, message: "No pending friend request from this user." }, 400);
        }
        // Verify request exists
        if (!outgoingRequests.includes(friendID)) {
            return createResponse({ success: false, message: "Other user request revoked." }, 400);
        }

        // Remove from requests
        incomingRequests = incomingRequests.filter(id => id !== friendID);
        outgoingRequests = outgoingRequests.filter(id => id !== playerID);

        // Add to friends list
        if (!friends.includes(friendID)) friends.push(friendID);
        if (!friendFriends.includes(playerID)) friendFriends.push(playerID);

        // Update accepting player's records
        query = `UPDATE users SET incoming_requests = ?, friends = ? WHERE id = ?`;
        await DB.prepare(query).bind(toCSV(incomingRequests), toCSV(friends), playerID).run();

        // Update sender's records
        query = `UPDATE users SET outgoing_requests = ?, friends = ? WHERE id = ?`;
        await DB.prepare(query).bind(toCSV(outgoingRequests), toCSV(friendFriends), friendID).run();

        return createResponse({ success: true, message: "Friend request accepted." });
    } catch (error) {
        console.error("Error accepting friend request:", error);
        return createResponse({ error: "Failed to accept friend request" }, 500);
    }
}

// Send a challenge request with optimized updates
async function challengeFriend(playerID, url, DB) {
    const friendID = url.searchParams.get("friendID");
    if (!playerID || !friendID) {
        return new Response("Missing gameID or playerID", { status: 400 });
    }

    try {
        // Fetch outgoing challenges for the challenger (sender)
        let query = `SELECT outgoing_challenges FROM users WHERE id = ?`;
        let challenger = await DB.prepare(query).bind(playerID).first();
        let outgoingChallenges = parseCSV(challenger?.outgoing_challenges);

        // Fetch incoming challenges for the recipient
        query = `SELECT incoming_challenges FROM users WHERE id = ?`;
        let recipient = await DB.prepare(query).bind(friendID).first();
        let incomingChallenges = parseCSV(recipient?.incoming_challenges);

        // Check if the challenge already exists
        if (outgoingChallenges.includes(friendID) && incomingChallenges.includes(playerID)) {
            return createResponse({ success: false, message: "Challenge already exists." }, 400);
        }

        let updated = false;

        // Add missing entries only if necessary
        if (!outgoingChallenges.includes(friendID)) {
            outgoingChallenges.push(friendID);
            updated = true;

            // Update the sender's outgoing challenges
            query = `UPDATE users SET outgoing_challenges = ? WHERE id = ?`;
            await DB.prepare(query).bind(toCSV(outgoingChallenges), playerID).run();
        }

        if (!incomingChallenges.includes(playerID)) {
            incomingChallenges.push(playerID);
            updated = true;

            // Update the recipient's incoming challenges
            query = `UPDATE users SET incoming_challenges = ? WHERE id = ?`;
            await DB.prepare(query).bind(toCSV(incomingChallenges), friendID).run();
        }

        if (!updated) {
            return createResponse({ success: false, message: "Challenge already present, no updates made." }, 400);
        }

        return createResponse({ success: true, message: "Challenge sent or restored." });
    } catch (error) {
        console.error("Error sending challenge:", error);
        return createResponse({ error: "Failed to send challenge" }, 500);
    }
}


// Accept a challenge and create a game
async function acceptChallenge(playerID, url, DB, GAME_ROOM) {
    const friendID = url.searchParams.get("friendID");
    if (!playerID || !friendID) {
        return new Response("Missing gameID or playerID", { status: 400 });
    }

    try {
        // Fetch incoming challenges for accepting player
        let query = `SELECT incoming_challenges FROM users WHERE id = ?`;
        let player = await DB.prepare(query).bind(playerID).first();
        let incomingChallenges = parseCSV(player?.incoming_challenges);

        // Fetch outgoing challenges for challenger
        query = `SELECT outgoing_challenges FROM users WHERE id = ?`;
        let friend = await DB.prepare(query).bind(friendID).first();
        let outgoingChallenges = parseCSV(friend?.outgoing_challenges);

        // Ensure both players have the challenge in their respective lists
        if (!incomingChallenges.includes(friendID) || !outgoingChallenges.includes(playerID)) {
            return createResponse({ success: false, message: "Challenge not found." }, 400);
        }

        // Remove the challenge from both lists
        incomingChallenges = incomingChallenges.filter(id => id !== friendID);
        outgoingChallenges = outgoingChallenges.filter(id => id !== playerID);

        // Update the database to remove the challenge
        query = `UPDATE users SET incoming_challenges = ? WHERE id = ?`;
        await DB.prepare(query).bind(toCSV(incomingChallenges), playerID).run();

        query = `UPDATE users SET outgoing_challenges = ? WHERE id = ?`;
        await DB.prepare(query).bind(toCSV(outgoingChallenges), friendID).run();
        
        const response = await handleGameCreation(playerID, url, null, GAME_ROOM, DB, 0);
        const json = await response.json();
        console.log("json", JSON.stringify(json));
        const gameID = json.gameID;
        
        if (gameID) {
            // await joinGame(playerID, url, null, GAME_ROOM, DB, 0, gameID);
            await joinGame(friendID, url, null, GAME_ROOM, DB, 0, gameID);
            return createResponse({ success: true, message: "Game joined!", gameID: gameID });
        }
        else return createResponse({ message_type: "error", error: "Failed to create game."}, 500);
    } catch (error) {
        console.error("Error accepting challenge:", error);
        return createResponse({ error: "Failed to accept challenge" }, 500);
    }
}


async function getGameData(playerID, url, request, DB) {
    if (!playerID) return createResponse({message_type: "error", error: "Player ID is required." }, 400);
    if (!verifyToken(request)) return createResponse({message_type: "error", error: "Authentication Failed" }, 403);

    const query = `SELECT * FROM games WHERE id = ?;`;
    const result = await DB.prepare(query).bind(playerID).all();

    if (result) {
        return createResponse(result);
    } else {
        return createResponse({message_type: "error", error: "Game not found." }, 404);
    }
}


async function getPlayerStats(playerID, DB) {
    if (!playerID) return createResponse({message_type: "error", error: "Player ID is required." }, 400);

    const query = `SELECT * FROM users WHERE id = ?;`;
    const result = await DB.prepare(query).bind(playerID).first();
    console.log("result" + JSON.stringify(result));

    if (result) {
        return createResponse(result);
    } else {
        return createResponse({message_type: "error", error: "Player not found." }, 404);
    }
}