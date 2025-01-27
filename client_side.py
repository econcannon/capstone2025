import asyncio
import websockets
import http.client
import json
import chess

player_id = "EricC"
BASE_URL = "chess-app-v5.concannon-e.workers.dev"

def display_fen_as_board(fen):
    board = chess.Board(fen)
    board_str = str(board)  # Get a string representation of the board
    print(board_str)

async def create_game(conn, token):
    headers = {
        "Content-Type": "application/json",
        "authorization": token
    }
    conn.request("POST", f"/create?playerID={player_id}&ai={True}&depth=1", body=None, headers=headers)
    response = conn.getresponse()
    
    if response.status == 200:
        data = json.loads(response.read().decode())
        game_id = data.get("gameID")
        print(f"New game created with ID: {game_id}")
        return game_id
    else:
        print(f"Failed to create game. Status code: {response.status}")
        return None


async def join_game():
    game_id = input("Enter the game ID to join: ")
    return game_id


async def play_game(websocket):
    player_color = None

    try:
        while True:
            print("Next loop: waiting for message")
            response = await websocket.recv()
            data = json.loads(response)
            print(data, type(data))

            # Handle game state update
            if data.get("message_type") == "game-state":
                player_color = data["color"]
                fen = data['fen']
                print(f"Game State Updated: {fen}")
                print(f"You are playing as {player_color}")
                display_fen_as_board(fen)
                
                
                # Prompt for move if it's the player's turn
                if data['turn'] == player_color[0]:
                    await send_move(websocket)

            # Handle opponent's move
            elif data.get("message_type") == "move":
                move = data.get("move")
                print(f"Opponent moved: {move['from']} to {move['to']}")
                fen = data.get("fen")
                display_fen_as_board(fen)
                # Prompt for move if it's the player's turn
                if data['turn'] == player_color[0]:
                    print("Your turn!")
                    await send_move(websocket)

    except websockets.exceptions.ConnectionClosed as e:
        print(f"WebSocket closed unexpectedly: {e.reason}")
        await handle_reconnect()


async def send_move(websocket):

    valid_move = False
    while not valid_move:
        from_square, to_square = getMoveLogic()

        await websocket.send(json.dumps({
            "message_type": "move",
            "playerID": player_id,
            "move": {
                "from": from_square,
                "to": to_square
            }
        }))
        print(f"Move sent: {from_square} to {to_square}")

        try:
            confirmation = await websocket.recv()
            print(confirmation)
            response = json.loads(confirmation)
            print(response)

            if response.get("message_type") == "confirmation":
                valid_move = True
                fen = response['fen']
                display_fen_as_board(fen)
                print(f"Move confirmed: {fen}")
            else:
                print(f"Illegal move: {response.get('error')}")
        except websockets.exceptions.ConnectionClosed as e:
            print(f"WebSocket closed during move confirmation: {e.reason}")
            await handle_reconnect()


def getMoveLogic():
    from_square = input("Enter move from (e.g., e2): ")
    to_square = input("Enter move to (e.g., e4): ")
    return from_square, to_square


async def handle_reconnect():
    print("Attempting to reconnect...")
    await asyncio.sleep(5)  # Wait before reconnecting
    await main()  # Re-run the main function to reconnect


async def main():
    choice = input("Create (1) or Join (2) a game? (1/2): ")
    player_id = "EricC"
    password = "Fire1776"
    endpoint = f"/player/login?playerID={player_id}&password={password}"

    conn = http.client.HTTPSConnection(BASE_URL)

    conn.request("GET", endpoint, headers={"Content-Type": "application/json"}
)
    response = conn.getresponse()
    token = json.loads(response.read().decode()).get("token")
    if response.status == 200:
        print(f"Welcome {player_id}!")

    if choice == "1":
        game_id = await create_game(conn, token)
    elif choice == "2":
        game_id = await join_game()
    else:
        print("Invalid choice.")
        return

    URL = f"wss://{BASE_URL}/connect?gameID={game_id}&playerID={player_id}"
    token_header = {"authorization": token}
    async with websockets.connect(URL, additional_headers=token_header) as websocket:
        print(f"Connected to game {game_id} as {player_id}")
        await play_game(websocket)


if __name__ == "__main__":
    asyncio.run(main())
