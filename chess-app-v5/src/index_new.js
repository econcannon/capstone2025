import { Chess } from 'chess.js';
import { generate } from "random-words";
import { DurableObject } from 'cloudflare:workers';

const BASE_URL = "chess-app-v5.concannon-e.workers.dev";
const STOCKFISH_URL = "https://stockfish.online/api/s/v2.php";

// Standardized Response Helper
function createResponse(body, status = 200) {
    return new Response(JSON.stringify(body), {
        status,
        headers: { "Content-Type": "application/json" }
    });
}


function standard_game_info(game, playerID, players_color, players, message_type = "game-state") {
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


export class ChessGame extends DurableObject {
    constructor(ctx, env) {
        super(ctx, env);
        console.log("New Durable Object instance created");
        this.storage = ctx.storage;
        this.game = null;
        this.players = [];
        this.players_color = { white: null, black: null };
        this.gameID = null;
        this.depth = 10;
        this.ai = false;
        this.initializeGameState();
    }

    async initializeGameState() {
        const [storedState, storedPlayers, storedPlayersColor, storedAi, storedDepth] = await Promise.all([
            this.storage.get("gameState"),
            this.storage.get("players"),
            this.storage.get("players_color"),
            this.storage.get("ai"),
            this.storage.get("depth"),
        ]);

        this.game = storedState ? new Chess(storedState) : new Chess();
        this.players_color = storedPlayersColor || { white: null, black: null };
        this.players = storedPlayers || [];
        this.ai = storedAi || false;
        this.depth = storedDepth || 10;
        console.log("initializing game state ai: " + this.ai.toString() + " players: " + this.players.toString() + " colors: " + JSON.stringify(this.players_color));
    }

    async fetch(request) {
        const url = new URL(request.url);
        const playerID = url.searchParams.get("playerID");
        
        if (!this.gameID) {
            this.gameID = url.searchParams.get("gameID");
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
                return createResponse(standard_game_info(this.game, playerID, this.players_color, this.players));
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
            if (!this.players.includes(playerID)) {
                this.players.push(playerID);
                if (ai && this.players.length === 1) {
                    console.log("Entered here: " + ai.toString());
                    this.players.push("AI");
                    await this.storage.put("ai", true);
                    await this.storage.put("depth", depth);
                    this.ai = true;
                }
                else {
                    await this.storage.put("ai", false);
                }
                await this.storage.put("players", this.players);
                console.log("Entered players: " + this.players.toString());
            }
            else {
                return createResponse({message_type: "error", error: "You are already in this game!" }, 403);
            }

            return createResponse(standard_game_info(this.game, playerID, this.players_color, this.players));
        } catch (error) {
            return createResponse({message_type: "error", error: "Error updating durable object storage." }, 500);
        }

    }

    async handleWebSocket(request) {
        const url = new URL(request.url);
        const playerID = url.searchParams.get("playerID");

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
        await serverSocket.send(JSON.stringify(standard_game_info(this.game, playerID, this.players_color, this.players)));

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
    
            const confirmationPayload = JSON.stringify(standard_game_info(this.game, playerID, this.players_color, this.players, "confirmation"));
            ws.send(confirmationPayload);
            console.log("Process move: " + this.ai.toString());
            if (this.ai) {
                // Get AI move from Stockfish
                await this.handleAIMove(ws, playerID);
            } else {
                this.broadcastMove(ws, result);
            }
        } else {
            ws.send(JSON.stringify(createResponse({ message_type: "error", error: "Invalid move" }, 400)));
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
                standard_game_info(this.game, playerID, this.players_color, this.players, "game-state")
            );
            ws.send(aiMovePayload);
        } else {
            ws.send(JSON.stringify(createResponse({ message_type: "error", error: "AI move failed" }, 500)));
        }
    } 
    

    // Function to generate the payload to be sent to the opponent
    generateMovePayload(game, senderID, playersColor, players, moveResult) {
        return JSON.stringify({
            ...standard_game_info(game, senderID, playersColor, players, "move"),
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
    async broadcastMove(ws, moveResult) {
        const payload = this.generateMovePayload(this.game, senderID, this.players_color, this.players, moveResult);
        await this.sendToOpponent(ws, payload);
    }


    // // Broadcast message to the opponent only
    // async broadcastToOpponent(senderID, moveResult) {
    //     const opponentSocket = this.ctx.getWebSockets().find((ws) => {
    //         const { playerID } = ws.deserializeAttachment();
    //         return playerID !== senderID;
    //     });

    //     if (opponentSocket) {
    //         const opponentPayload = JSON.stringify(
    //             {
    //                 ...standard_game_info(this.game, senderID, this.players_color, this.players, "move"),
    //                 move: { from: moveResult["from"], to: moveResult["to"] },
    //             },
    //         );
    //         opponentSocket.send(opponentPayload);
    //     } else {
    //         console.log(`No opponent connected to receive message.`);
    //     }
    // }

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
                return handleGameCreation(playerID, url, GAME_ROOM, DB);
            case "player":
                return handlePlayerActions(url_path, url, playerID, DB, GAME_ROOM);
            case "connect":
                return handleConnect(url, request, GAME_ROOM);
            default:
                return createResponse({message_type: "error", error: "Not Found" }, 404);
        }
    }
};

async function handleGameCreation(playerID, url, GAME_ROOM, DB) {
    if (!playerID) return createResponse({message_type: "error", error: "Player ID required." }, 400);
    
    const max = 10000;
    const min = 1;
    const gameString = generate(3).join("-") + String(Math.floor(Math.random() * (max - min) + min));
    const gameRoomID = GAME_ROOM.idFromString(gameString);
    const gameRoom = GAME_ROOM.get(gameRoomID);
    const success = await insertNewGame(playerID, gameRoomID, DB);
    let ai = false;
    ai = url.searchParams.get("ai")?.toLowerCase() === "true";
    const difficulty = url.searchParams.get("difficulty");
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
    const gameID = GAME_ROOM.idFromString(url.searchParams.get("gameID"));
    const playerID = url.searchParams.get("playerID");

    if (!gameID || !playerID) {
        return new Response("Missing gameID or playerID", { status: 400 });
    }

    // Retrieve the existing game Durable Object by ID
    const gameRoomId = GAME_ROOM.idFromString(gameID);
    const gameRoom = GAME_ROOM.get(gameRoomId);

    return gameRoom.fetch(request);
}


async function handlePlayerActions(url_path, url, playerID, DB, GAME_ROOM) {
    switch (url_path[2]) {
        case "login":
            return loginPlayer(playerID, url, DB);
        case "join-game":
            return joinGame(playerID, url, GAME_ROOM, DB);
        case "games":
            return getGameInfo(playerID, GAME_ROOM, DB);
        case "register":
            return registerPlayer(playerID, url, DB);
        case "end-game":
            return removeGameFromActive(playerID, url, DB);
        case "end-all-games":
            return removeAllGames(playerID, DB);
        default:
            return createResponse({message_type: "error", error: "Invalid action" }, 400);
    }
}


async function loginPlayer(playerID, url, DB) {
    const password = url.searchParams.get("password");
    const query = `SELECT * FROM users WHERE id = ? AND password = ?;`;

    const result = await DB.prepare(query).bind(playerID, password).first();
    if (result) {
        return createResponse({});
    } else {
        return createResponse({}, 404);
    }
}


async function joinGame(playerID, url, GAME_ROOM, DB) {
    const gameID = url.searchParams.get("gameID");
    const gameRoom = GAME_ROOM.get(GAME_ROOM.idFromString(gameID));
    const response = await gameRoom.fetch(
        new URL("/join-game?playerID=" + playerID + "&ai=false", url.origin)
    );

    if (response.ok) {
        const data = await response.json();
        if (data.message_type !== "error") {
            await insertNewGame(playerID, gameID, DB);
        }
    }
    return response;
}


async function insertNewGame(playerID, gameID, DB) {
    const query = `
        UPDATE users
        SET active_games = 
            COALESCE(active_games || ',', '') || ?
        WHERE id = ?;
    `;
    try {
        const result = await DB.prepare(query).bind(gameID.toString(), playerID).run();
        return result.success;
    } catch (error) {
        console.error("Error inserting new game:", error);
        return false;
    }
}


async function removeGameFromActive(playerID, url, DB) {
    const gameID = url.searchParams.get("gameID");
    const query = `
        UPDATE users
        SET active_games = 
            CASE 
                WHEN REPLACE(',' || active_games || ',', ',' || ? || ',', ',') = ',' THEN NULL
                ELSE SUBSTR(
                    REPLACE(',' || active_games || ',', ',' || ? || ',', ','),
                    2,
                    LENGTH(REPLACE(',' || active_games || ',', ',' || ? || ',', ',')) - 2
                )
            END
        WHERE id = ?;
    `;

    try {
        const result = await DB.prepare(query).bind(gameID, gameID, gameID, playerID).run();
        return createResponse();
    } catch (error) {
        console.error("Error removing game from active games:", error);
        return false;
    }
}


// add fetch response for durable object
async function removeAllGames(playerID, DB, GAME_ROOM) {
    // Step 1: Fetch all active games for the player
    const query = `
        SELECT active_games 
        FROM users 
        WHERE id = ?;
    `;

    try {
        const result = await DB.prepare(query).bind(playerID).first();
        if (!result || !result.active_games) {
            console.log(`No active games found for player: ${playerID}`);
            return createResponse();
        }

        const activeGames = result.active_games.split(','); // Assuming comma-separated game IDs

        // Step 2: Iterate through each game and update its Durable Object storage
        for (const gameID of activeGames) {
            const gameRoomId = GAME_ROOM.idFromString(gameID);
            const gameRoom = GAME_ROOM.get(gameRoomId);

            try {
                const response = await gameRoom.fetch("https://" + BASE_URL + "/update-game-status", {
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
        const updateQuery = `
            UPDATE users
            SET active_games = NULL 
            WHERE id = ?;
        `;
        await DB.prepare(updateQuery).bind(playerID).run();

        return createResponse();
    } catch (error) {
        console.error("Error removing games from active games:", error);
        return false;
    }
}


async function getGameInfo(playerID, GAME_ROOM, DB) {
    if (!playerID) return createResponse({message_type: "error", error: "Player ID is required." }, 400);

    const query = `SELECT active_games FROM users WHERE id = ?;`;
    const result = await DB.prepare(query).bind(playerID).all();

    if (result.success && result.results.length === 0) {
        return createResponse({ games: [] });
    }

    const activeGames = String(result.results[0].active_games);
    const gameIDs = activeGames ? activeGames.split(',') : [];

    const gamesInfo = await Promise.all(
        gameIDs.map(async (gameID) => {
            const gameRoom = GAME_ROOM.get(GAME_ROOM.idFromString(gameID));
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
