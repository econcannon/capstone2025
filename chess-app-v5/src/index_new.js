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
        //this.gameID = null;
        this.gameID = ctx.id.toString(); 
        this.depth = 10;
        this.ai = false;
        this.initializeGameState();
    }

    async initializeGameState() {
        const [storedState, storedPlayers, storedPlayersColor, storedAi, storedDepth, storedGameID] = await Promise.all([
            this.storage.get("gameState"),
            this.storage.get("players"),
            this.storage.get("players_color"),
            this.storage.get("ai"),
            this.storage.get("depth"),
            this.storage.get("gameID")
        ]);

        this.game = storedState ? new Chess(storedState) : new Chess();
        this.players_color = storedPlayersColor || { white: null, black: null };
        this.players = storedPlayers || new Set();
        this.ai = storedAi || false;
        this.depth = storedDepth || 10;
        this.gameID = storedGameID || null;
        console.log("initializing game state ai: " + this.ai.toString() + " players: " + this.players.toString() + " colors: " + JSON.stringify(this.players_color));
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
                return createResponse(standardGameInfo(this.game, playerID, this.players_color, this.players));
            case "/update-game-info":
                return this.handleUpdateGame(request);
            default:
                return createResponse({ error: "Not Found" }, 404);
        }
    }

    async handleJoinGame(playerID, ai, depth = 10) {
        if (!playerID) return createResponse({message_type: "error", error: "Player ID required" }, 400);
        
        try {
            if (this.players.length >= 2) {
                return createResponse({message_type: "error", error: "Game is full. Cannot join." }, 403);
            }
            if (!this.players.has(playerID)) {
                this.players.add(playerID);
                if (ai && this.players.length === 1) {
                    console.log("Entered here: " + ai.toString());
                    this.players.add("AI");
                    await this.storage.put("ai", true);
                    await this.storage.put("depth", depth);
                    this.ai = true;
                }
                else {
                    await this.storage.put("ai", false);
                }
                await this.storage.put("players", this.players);
                console.log("Entered players: " + Array.from(this.players).toString());
            }
            else {
                return createResponse({message_type: "error", error: "You are already in this game!" }, 403);
            }

            return createResponse(standardGameInfo(this.game, playerID, this.players_color, this.players));
        } catch (error) {
            return createResponse({message_type: "error", error: "Error updating durable object storage." }, 500);
        }

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


    async handleWebSocket(request) {
        const url = new URL(request.url);
        const playerID = url.searchParams.get("playerID");

        const joinGameResponse = this.handleJoinGame(playerID, this.ai, this.depth);
        if (joinGameResponse.message_type === "error") {
            return joinGameResponse
        }

        const [clientSocket, serverSocket] = new WebSocketPair();
        this.ctx.acceptWebSocket(serverSocket);

        // Attach playerID to WebSocket for identification
        serverSocket.serializeAttachment({ playerID });

        // Assign players to sides if not already assigned
        if (!this.players_color.white) {
            this.players_color.white = playerID;
            await fetch(`https://${BASE_URL}/update-game-players`, {
                method: "POST",
                body: JSON.stringify({
                    gameID: this.gameID,
                    player_white: playerID,
                    player_black: this.players_color.black
                })
            });
        } else if (!this.players_color.black && this.players_color.white !== playerID) {
            this.players_color.black = playerID;
            await fetch(`https://${BASE_URL}/update-game-players`, {
                method: "POST",
                body: JSON.stringify({
                    gameID: this.gameID,
                    player_white: this.players_color.white,
                    player_black: playerID
                })
            });
        }

        await this.storage.put("players_color", this.players_color);
        await serverSocket.send(JSON.stringify(standardGameInfo(this.game, playerID, this.players_color, this.players)));

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
            await fetch(`https://${BASE_URL}/save-move`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    gameID: this.gameID,
                    move_number: this.game.history().length,
                    from: result.from,
                    to: result.to,
                    san: result.san
                })
            });
    
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
            // Add this block to finalize game state
            const winner = this.game.turn() === 'w' ? this.players_color.black : this.players_color.white;
            const status = this.game.isCheckmate() ? "checkmate" :
                         this.game.isDraw() ? "draw" : "unknown";
            
            await fetch(`https://${BASE_URL}/end-game`, {
                method: "POST",
                body: JSON.stringify({
                    gameID: this.gameID,
                    winner: status === "draw" ? null : winner,
                    status
                })
            });
        
            await fetch(`https://${BASE_URL}/update-stats`, {
                method: "POST",
                body: JSON.stringify({ gameID: this.gameID })
            });
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


    async handleAIMove(ws, playerID) {
        const aiMove = await this.getAIMove(this.game.fen(), this.depth);
        console.log("AI Move: " + JSON.stringify(aiMove));

        if (aiMove) {
            this.game.move(aiMove);
            await this.storage.put("gameState", this.game.fen());

            const aiMovePayload = JSON.stringify(
                standardGameInfo(this.game, playerID, this.players_color, this.players, "game-state")
            );
            ws.send(aiMovePayload);
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
        const opponentSocket = this.ctx.getWebSockets().find((ws) => ws !== senderSocket);

        if (opponentSocket) {
            opponentSocket.send(payload);
        } else {
            console.log(`No opponent connected to receive message.`);
        }
    }


    // Broadcast message to the opponent only
    async broadcastMove(ws, moveResult, senderID) {
        const payload = this.generateMovePayload(this.game, senderID, this.players_color, this.players, moveResult);
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

        const url_path = url.pathname.split('/');
        
        switch (url_path[1]) {
            case "create":
                return handleGameCreation(playerID, url, request, GAME_ROOM, DB);
            case "player":
                return handlePlayerActions(url_path, url, request, playerID, DB, GAME_ROOM);
            case "connect":
                return handleConnect(url, request, GAME_ROOM);
            case "save-move":
                return handleSaveMove(request, env.DB);
            case "end-game":
                return handleEndGame(request, env.DB);
            case "update-stats":
                return handleUpdateStats(request, env.DB);
            case "replay":
                return handleReplayGame(request, env.DB);
            case "update-game-players":
                return handleUpdateGamePlayers(request, env.DB);
            default:
                return createResponse({message_type: "error", error: "Not Found" }, 404);
        }
    }
};

async function handleGameCreation(playerID, url, request, GAME_ROOM, DB) {
    if (!playerID) return createResponse({message_type: "error", error: "Player ID required." }, 400);
    if (!verifyToken(request)) return createResponse({message_type: "error", error: "Authentication Failed" }, 403);

    const max = 999999999;
    const min = 0;
    const gameString = generate(3).join("-") + String(Math.floor(Math.random() * (max - min) + min));
    const gameRoomID = GAME_ROOM.idFromName(gameString);
    const gameRoom = GAME_ROOM.get(gameRoomID);
    const success = await insertNewGame(playerID, gameString, DB);
    let ai = false;
    ai = url.searchParams.get("ai")?.toLowerCase() === "true";
    const difficulty = url.searchParams.get("difficulty");

    await DB.prepare(`
        INSERT INTO games (id, player_white, status)
        VALUES (?, ?, 'pending')
    `).bind(gameRoomID.toString(), playerID).run();

    await gameRoom.fetch(
        new URL("/join-game?playerID=" + playerID + "&ai=" + ai + "&difficulty=" + difficulty, url.origin)
    );
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

// Save individual moves
async function handleSaveMove(request, DB) {
    try {
        const data = await request.json();
        const insertQuery = `
            INSERT INTO moves (game_id, move_number, from_square, to_square, san)
            VALUES (?, ?, ?, ?, ?)
        `;
        await DB.prepare(insertQuery)
            .bind(data.gameID, data.move_number, data.from, data.to, data.san)
            .run();
        
        // Update total moves in games table
        await DB.prepare(`
            UPDATE games SET total_moves = total_moves + 1 WHERE id = ?
        `).bind(data.gameID).run();
        
        return createResponse({ success: true });
    } catch (error) {
        console.error("Move save error:", error);
        return createResponse({ error: "Failed to save move" }, 500);
    }
}

// Handle game end
async function handleEndGame(request, DB) {
    try {
        const data = await request.json();
        const updateQuery = `
            UPDATE games 
            SET winner = ?, status = ?, ended_at = CURRENT_TIMESTAMP 
            WHERE id = ?
        `;
        await DB.prepare(updateQuery)
            .bind(data.winner, data.status, data.gameID)
            .run();
        
        // Remove game from active games
        const game = await DB.prepare("SELECT player_white, player_black FROM games WHERE id = ?")
            .bind(data.gameID).first();
        
        const players = [game.player_white, game.player_black]
            .filter(p => p && p !== "AI");
            
        for (const playerID of players) {
            await removeGameFromActive(playerID, data.gameID, DB);
        }
        
        return createResponse({ success: true });
    } catch (error) {
        console.error("End game error:", error);
        return createResponse({ error: "Failed to end game" }, 500);
    }
}

// Update player stats
async function handleUpdateStats(request, DB) {
    try {
        const data = await request.json();
        const game = await DB.prepare(`
            SELECT total_moves, player_white, player_black, winner 
            FROM games WHERE id = ?
        `).bind(data.gameID).first();

        const players = [game.player_white, game.player_black]
            .filter(p => p && p !== "AI");

        for (const playerID of players) {
            const isWinner = playerID === game.winner;
            const isDraw = !game.winner;
            
            const updateQuery = `
                UPDATE users SET
                    games_played = games_played + 1,
                    wins = wins + ?,
                    losses = losses + ?,
                    ties = ties  + ?
                    moves_per_game = FLOOR(((moves_per_game * games_played) + ?) / (games_played + 1))
                WHERE id = ?
            `;
            
            await DB.prepare(updateQuery).bind(
                isWinner ? 1 : 0,
                !isWinner && !isDraw ? 1 : 0,
                isDraw ? 1 : 0,
                game.total_moves,
                playerID
            ).run();
        }
        
        return createResponse({ success: true });
    } catch (error) {
        console.error("Stats update error:", error);
        return createResponse({ error: "Failed to update stats" }, 500);
    }
}

// Get game replay data
async function handleReplayGame(request, DB) {
    try {
        const gameID = new URL(request.url).searchParams.get("gameID");
        const { results } = await DB.prepare(`
            SELECT * FROM moves 
            WHERE game_id = ?
            ORDER BY move_number
        `).bind(gameID).all();
        
        return createResponse({ moves: results });
    } catch (error) {
        console.error("Replay error:", error);
        return createResponse({ error: "Failed to get replay" }, 500);
    }
}

// Update player color assignments
async function handleUpdateGamePlayers(request, DB) {
    try {
        const data = await request.json();
        await DB.prepare(`
            UPDATE games 
            SET player_white = ?, player_black = ?
            WHERE id = ?
        `).bind(data.player_white, data.player_black, data.gameID).run();
        return createResponse({ success: true });
    } catch (error) {
        console.error("Player update error:", error);
        return createResponse({ error: "Failed to update players" }, 500);
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
            return seeFriendRquests(playerID, DB);
        case "send-friend-request":
            return sendFriendRequest(playerID, url, DB);
        case "accept-friend-request":
            return acceptFriendRequest(playerID, url, DB);
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


async function joinGame(playerID, url, request, GAME_ROOM, DB) {
    if (!verifyToken(request)) return createResponse({message_type: "error", error: "Authentication Failed" }, 403);

    const gameID = url.searchParams.get("gameID");
    const gameRoom = GAME_ROOM.get(GAME_ROOM.idFromName(gameID));
    const response = await gameRoom.fetch(
        new URL("/join-game?playerID=" + playerID + "&ai=false", url.origin)
    );

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
        const result = await DB.prepare(query).bind(playerID).run();
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
        const result = await DB.prepare(query).bind(playerID).run();
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
        const result = await DB.prepare(query).bind(playerID).run();
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
    const query = `SELECT friends FROM players WHERE id = ?`;
    try {
        const result = await DB.prepare(query).bind(playerID).run();
        return createResponse({ friends: parseCSV(result?.friends) });
    } catch (error) {
        console.error("Error retrieving friends:", error);
        return createResponse({ error: "Failed to retrieve friends" }, 500);
    }
}

// Retrieve both incoming and outgoing friend requests
async function seeFriendRequests(playerID, DB) {
    const query = `SELECT incoming_requests, outgoing_requests FROM players WHERE id = ?`;
    try {
        const result = await DB.prepare(query).bind(playerID).run();
        return createResponse({
            incoming_requests: parseCSV(result?.incoming_requests),
            outgoing_requests: parseCSV(result?.outgoing_requests)
        });
    } catch (error) {
        console.error("Error retrieving friend requests:", error);
        return createResponse({ error: "Failed to retrieve friend requests" }, 500);
    }
}

// Send a friend request
async function sendFriendRequest(playerID, friendID, DB) {
    try {
        // Fetch outgoing requests for sender
        let query = `SELECT outgoing_requests FROM players WHERE id = ?`;
        let sender = await DB.prepare(query).bind(playerID).run();
        let outgoingRequests = parseCSV(sender?.outgoing_requests);

        // Fetch incoming requests for receiver
        query = `SELECT incoming_requests FROM players WHERE id = ?`;
        let receiver = await DB.prepare(query).bind(friendID).run();
        let incomingRequests = parseCSV(receiver?.incoming_requests);

        // Prevent duplicate requests
        if (outgoingRequests.includes(friendID) || incomingRequests.includes(playerID)) {
            return createResponse({ success: false, message: "Friend request already sent or received." }, 400);
        }

        outgoingRequests.push(friendID);
        incomingRequests.push(playerID);

        // Update sender's outgoing requests
        query = `UPDATE players SET outgoing_requests = ? WHERE id = ?`;
        await DB.prepare(query).bind(toCSV(outgoingRequests), playerID).run();

        // Update receiver's incoming requests
        query = `UPDATE players SET incoming_requests = ? WHERE id = ?`;
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
        let query = `SELECT incoming_requests, friends FROM players WHERE id = ?`;
        let player = await DB.prepare(query).bind(playerID).run();
        let incomingRequests = parseCSV(player?.incoming_requests);
        let friends = parseCSV(player?.friends);

        // Fetch outgoing requests and friends for sender
        query = `SELECT outgoing_requests, friends FROM players WHERE id = ?`;
        let friend = await DB.prepare(query).bind(friendID).run();
        let outgoingRequests = parseCSV(friend?.outgoing_requests);
        let friendFriends = parseCSV(friend?.friends);

        // Verify request exists
        if (!incomingRequests.includes(friendID)) {
            return createResponse({ success: false, message: "No pending friend request from this user." }, 400);
        }

        // Remove from requests
        incomingRequests = incomingRequests.filter(id => id !== friendID);
        outgoingRequests = outgoingRequests.filter(id => id !== playerID);

        // Add to friends list
        if (!friends.includes(friendID)) friends.push(friendID);
        if (!friendFriends.includes(playerID)) friendFriends.push(playerID);

        // Update accepting player's records
        query = `UPDATE players SET incoming_requests = ?, friends = ? WHERE id = ?`;
        await DB.prepare(query).bind(toCSV(incomingRequests), toCSV(friends), playerID).run();

        // Update sender's records
        query = `UPDATE players SET outgoing_requests = ?, friends = ? WHERE id = ?`;
        await DB.prepare(query).bind(toCSV(outgoingRequests), toCSV(friendFriends), friendID).run();

        return createResponse({ success: true, message: "Friend request accepted." });
    } catch (error) {
        console.error("Error accepting friend request:", error);
        return createResponse({ error: "Failed to accept friend request" }, 500);
    }
}

