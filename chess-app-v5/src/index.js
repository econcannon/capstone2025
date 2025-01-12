import { Chess } from 'chess.js';
import { DurableObject } from 'cloudflare:workers';
const BASE_URL = "chess-app-v3.concannon-e.workers.dev";

export class ChessGame extends DurableObject {
    constructor(ctx, env) {
        super(ctx, env);
        this.storage = ctx.storage;
        this.game = null;
		this.players = [];
        this.players_color = {white: null, black: null};
		this.gameID = null;

        // Restore game state and player info from storage
        this.initializeGameState();
    }

    // Initialize or restore game state and players
    async initializeGameState() {
        const [storedState, storedPlayers, storedPlayersColor] = await Promise.all([
            this.storage.get("gameState"),
            this.storage.get("players"),
			this.storage.get("players_color"),
        ]);

        this.game = storedState ? new Chess(storedState) : new Chess();
        this.players_color = storedPlayersColor || {white: null, black: null};
		this.players = storedPlayers || [];

        console.log(storedState ? "Game state restored." : "New game initialized.");
    }

    // Handle HTTP requests and WebSocket upgrades
    async fetch(request) {
		const url = new URL(request.url);
        if (!this.gameID){
        	this.gameID = url.searchParams.get("gameID");
		}

        if (url.pathname === "/connect" && request.headers.get("Upgrade") === "websocket") {
            return this.handleWebSocket(request);
        }

		if (url.pathname === "/join-game" && request.method === "GET") {
			const playerID = url.searchParams.get("playerID");
			try {
				// Update players list if not already present
				if (!this.players.includes(playerID)) {
					this.players.push(playerID);
					await this.storage.put("players", this.players);
				}
				console.log(JSON.stringify(this.players));
				return new Response(
					JSON.stringify({ players: this.players }),
					{ status: 200, headers: { "Content-Type": "application/json" } }
				);
			} catch (error) {
				return new Response(
					JSON.stringify({ error: "Error updating durable object storage." }),
					{ status: 500, headers: { "Content-Type": "application/json" } }
				);
			}
		}

		if (url.pathname === "/game-info" && request.method === "GET") {
            return new Response(JSON.stringify({turn: this.game.turn(), players: this.players}));
        }

        return new Response("Not Found", { status: 404 });
    }


    // Handle WebSocket connections
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
            console.log(`Player ${playerID} assigned as White`);
        } else if (!this.players_color.black && this.players_color.white !== playerID) {
            this.players_color.black = playerID;
            console.log(`Player ${playerID} assigned as Black`);
        }

        await this.storage.put("players_color", this.players_color);

        // Notify player of game state and their assigned color
        const color = (this.players_color.white === playerID) ? "white" : "black";
        serverSocket.send(JSON.stringify({
            type: "gameState",
            fen: this.game.fen(),
            color: color,
            turn: this.game.turn(),
            message: (color === "white" && this.game.turn() === 'w') ? "Your turn!" : "Waiting for opponent..."
        }));

        return new Response(null, { status: 101, webSocket: clientSocket });
    }

    // Handle incoming WebSocket messages
    async webSocketMessage(ws, msg) {
        const data = JSON.parse(msg);
        if (data.type === "move") {
            await this.processMove(ws, data);
        }
    }

    // Process player moves
    async processMove(ws, data) {
        const { playerID, move } = data;
        const isWhiteTurn = this.game.turn() === 'w';
        const isPlayerWhite = this.players_color.white === playerID;
        const isValidTurn = (isWhiteTurn && isPlayerWhite) || (!isWhiteTurn && !isPlayerWhite);

        if (!isValidTurn) {
            ws.send(JSON.stringify({type: "error", error: "Not your turn" }));
            return;
        }

        let result;
        try {
            result = this.game.move(move);
        } catch {
            result = null;
        }

        if (result) {
            console.log(`Move applied: ${JSON.stringify(result)}`);
            await this.storage.put("gameState", this.game.fen());

            // Notify player of successful move
            ws.send(JSON.stringify({
                type: "confirmation", 
                success: true,
                fen: this.game.fen(),
                status: this.game.isGameOver() ? "game over" : "ongoing",
				checkmate: this.game.isCheckmate()
            }));

            // Notify opponent
            this.broadcastToOpponent(playerID, {
                type: 'move',
                move: {from: result["from"], to: result["to"]},
                fen: this.game.fen(),
                turn: this.game.turn(),
				status: this.game.isGameOver() ? "game over" : "ongoing",
				checkmate: this.game.isCheckmate()
            });
        } else {
            console.warn(`Invalid move attempted by ${playerID}: ${JSON.stringify(move)}`);
            ws.send(JSON.stringify({type: "error", success: false }));
        }
    }

    // Broadcast message to the opponent only
    broadcastToOpponent(senderID, message) {
        const opponentSocket = this.ctx.getWebSockets().find((ws) => {
            const { playerID } = ws.deserializeAttachment();
            return playerID !== senderID;
        });

        if (opponentSocket) {
            opponentSocket.send(JSON.stringify(message));
        } else {
            console.log(`No opponent connected to receive message.`);
        }
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


// Main Worker for game creation and WebSocket routing
export default {
    async fetch(request, env) {
        const url = new URL(request.url);
		const playerID = url.searchParams.get("playerID");
        const { GAME_ROOM } = env;
        const { DB } = env;
        const url_path = url.pathname.split('/');
		console.log(JSON.stringify(url_path));

        if (url_path[1] === "create" && request.method === "POST") {
            // Generate a new game by creating a Durable Object instance
            const gameRoomId = GAME_ROOM.newUniqueId();
            // const gameRoom = GAME_ROOM.get(gameRoomId);
			const playerID = url.searchParams.get("playerID");

            console.log(`Created new game with ID: ${gameRoomId.toString()}`);
			const success = await insert_new_game(playerID, gameRoomId, DB);
			if (!success){
				return new Response(
					JSON.stringify({ error: "Database error occurred." }),
					{ status: 500, headers: { "Content-Type": "application/json" } }
				);
			}
            return new Response(
                JSON.stringify({ gameID: gameRoomId.toString() }),
                { status: 200, headers: { "Content-Type": "application/json" } }
            );
        }

        if (url_path[1] === "player" && (request.method === "POST" || request.method === "GET")) {
            
            if (url_path[2] === "login" && request.method === "GET") {
				const password = url.searchParams.get("password");
                const query = `SELECT * FROM users WHERE id = ? AND password = ?;`;
                const result = await DB.prepare(query).bind(playerID, password).first();
                console.log(JSON.stringify(result));
                if (result){
                    return new Response(
                        JSON.stringify({ success: true }),
                        { status: 200, headers: { "Content-Type": "application/json" } }
                    );
                } else {
                    return new Response(
                        JSON.stringify({ success: false }),
                        { status: 404, headers: { "Content-Type": "application/json" } }
                    );
                }
            }

			if (url_path[2] === "join" && request.method === "POST") {
				const gameID = url.searchParams.get("gameID");
				// Retrieve the existing game Durable Object by ID
				const gameRoomId = GAME_ROOM.idFromString(gameID);
				const gameRoom = GAME_ROOM.get(gameRoomId);
				await insert_new_game(playerID, gameID, DB);
				return gameRoom.fetch("https://"+BASE_URL+"/join-game?playerID="+playerID);
			}

			if (url_path[2] === "games" && request.method === "GET") {
				return get_game_info(playerID, GAME_ROOM, DB);
			}

            if (url_path[2] === "register" && request.method === "POST") {
				const password = url.searchParams.get("password");
				const email = url.searchParams.get("email");

				if (!password || !email || !playerID) {
					return new Response("Missing required fields (playerID, email, or password)", { status: 400 });
				}

                const query = `INSERT INTO users (id, password, email) VALUES (?, ?, ?);`;
                try {
					const result = await DB.prepare(query).bind(playerID, password, email).run();
					return new Response("User registered successfully.", { status: 200 });
				} catch (error) {
					if (error.message.includes("UNIQUE constraint failed") || error.message.includes("already exists")) {
						return new Response("PlayerID already taken. Please choose another.", { status: 400 });
					}
					return new Response("Error registering user. Please try again later.", { status: 500 });
				}
            }

            if (url_path[2] === "friends" && request.method === "POST") {
                if (url_path[3] === "/add" && request.method === "POST") {
                    // Not edited
                    return new Response(
                        JSON.stringify({ gameID: gameRoomId.toString() }),
                        { status: 200, headers: { "Content-Type": "application/json" } }
                    );
                }
                if (url_path[3] === "remove" && request.method === "POST") {
                    // Not edited
                    return new Response(
                        JSON.stringify({ gameID: gameRoomId.toString() }),
                        { status: 200, headers: { "Content-Type": "application/json" } }
                    );
                }
            }
        }

        if (url.pathname === "/connect" && request.headers.get("Upgrade") === "websocket") {
            const gameID = url.searchParams.get("gameID");
            const playerID = url.searchParams.get("playerID");
			
            if (!gameID || !playerID) {
                return new Response("Missing gameID or playerID", { status: 400 });
            }

            // Retrieve the existing game Durable Object by ID
            const gameRoomId = GAME_ROOM.idFromString(gameID);
            const gameRoom = GAME_ROOM.get(gameRoomId);

            return gameRoom.fetch(request);
        }

        return new Response("Not Found", { status: 404 });
    }
};


async function insert_new_game(playerID, gameID, DB) {
    const query = `
        UPDATE users
        SET active_games = 
            COALESCE(active_games || ',', '') || ?
        WHERE id = ?;
    `;

    try {
        const result = await DB.prepare(query).bind(gameID.toString(), playerID).run();

        if (result.success) {
			console.log("game inserted: ", gameID.toString(), playerID);
            return true;
        } else {
			console.log("game not inserted: ", gameID.toString(), playerID);
            return false;
        }
    } catch (error) {
        console.error("Error inserting new game:", error);
        return false;
    }
}


async function get_game_info(playerID, GAME_ROOM, DB){
	if (!playerID) {
		return new Response(
			{ error: "Player ID is required.", status: 400, headers: { "Content-Type": "application/json" } }
		);
	}

	const query = `
		SELECT active_games 
		FROM users
		WHERE id = ?;
	`;

	try {
		// Get ongoing games for the player
		const result = await DB.prepare(query).bind(playerID).all();
		
		if (result.success && result.results.length === 0) {
			return new Response(
				JSON.stringify({ games: [] }),
				{ status: 200, headers: { "Content-Type": "application/json" } }
			);
		}
		console.log("active_games result", result);
		const activeGames = String(result.results[0].active_games);  // Assume ongoing_games is an array of gameIDs
		console.log("active_games: ", activeGames);
		const gameIDs = activeGames ? activeGames.split(',') : [];

		console.log("URL: ", "https://"+BASE_URL+"/game-info");
		const gamesInfo = await Promise.all(
			gameIDs.map(async (gameID) => {
				const gameRoomId = GAME_ROOM.idFromString(gameID);
				const gameRoom = GAME_ROOM.get(gameRoomId);
				const response = await gameRoom.fetch("https://"+BASE_URL+"/game-info");
				const data = await response.json();
				console.log("data map", JSON.stringify(data));
				return {
					gameID: gameID,
					players: data.players,
					turn: data.turn
				};
			})
		);

		console.log("game info", JSON.stringify(gamesInfo));
		return new Response(
			JSON.stringify({ games: gamesInfo }),
			{ status: 200, headers: { "Content-Type": "application/json" } }
		);

	} catch (error) {
		console.error("Error fetching games:", error);
		return new Response(
			JSON.stringify({ error: "Database error getting game info" }),
			{ status: 200, headers: { "Content-Type": "application/json" } }
		);
	}
};