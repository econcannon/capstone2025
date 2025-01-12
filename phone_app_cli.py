import http.client
import json
import asyncio
from bleak import BleakScanner, BleakClient
import subprocess
import re

# UUIDs (match Arduino's characteristics)
SSID_CHAR_UUID = "8266532f-1fe1-4af9-97e1-3b7c04ef8201"
PASSWORD_CHAR_UUID = "91abf729-1b45-4147-b8f7-b93620e8bce1"
GAMEID_CHAR_UUID = "5f91bb09-093c-42d7-b615-a2b110369a2e"
PLAYERID_CHAR_UUID = "bcf9cb8c-78f4-4b22-8f2c-ad5df34a34cd"
RESET_CHAR_UUID = "cfb3a8c4-85c7-4e9f-9f0b-b1c6e22b15e2"

ARDUINO_NAME = "GIGA_R1_Bluetooth"
BASE_URL = "chess-app-v5.concannon-e.workers.dev"
PORT = 443
HEADERS = {"Content-Type": "application/json"}


class ChessAppCLI:
    def __init__(self):
        self.conn = http.client.HTTPSConnection(BASE_URL, PORT)
        self.authenticated = False
        self.player_id = ""
        self.password = ""
        self.ssid = "" 
        self.wifi_password = "" 
        self.game_id = "" 
        self.email = ""
        self.friends = []
        self.devices = []

    # -----------------------
    # Main Menu Loop
    # -----------------------
    async def main_menu(self):
        while True:
            print("\n=== Chess Game Manager ===")
            if not self.authenticated:
                print("1. Log In")
                print("2. Sign Up")
                print("3. Reset Password")
                print("4. Scan for Bluetooth Devices")
                print("5. Exit")
            else:
                print("1. Manage Friends")
                print("2. Manage Games")
                print("3. Scan for Bluetooth Devices")
                print("4. Log Out")

            choice = input("Select an option: ")
            if not self.authenticated:
                if choice == "1":
                    self.log_in()
                elif choice == "2":
                    self.sign_up()
                elif choice == "3":
                    self.reset_password()
                elif choice == "4":
                    await self.scan_and_connect_bluetooth()
                elif choice == "5":
                    print("Exiting...")
                    break
                else:
                    print("Invalid option. Please try again.")
            else:
                if choice == "1":
                    self.manage_friends()
                elif choice == "2":
                    await self.manage_games()
                elif choice == "3":
                    await self.scan_and_connect_bluetooth()
                elif choice == "4":
                    self.log_out()
                else:
                    print("Invalid option. Try again.")

    # -----------------------
    # Log In
    # -----------------------
    def log_in(self):
        self.player_id = input("Enter Player ID: ")
        self.password = input("Enter Password: ")

        if not self.player_id or not self.password:
            print("Error: Player ID and Password are required.")
            return

        try:
            endpoint = f"/player/login?playerID={self.player_id}&password={self.password}"
            self.conn.request("GET", endpoint, headers=HEADERS)
            response = self.conn.getresponse()

            if response.status == 200:
                print(f"Welcome {self.player_id}!")
                self.authenticated = True
            else:
                print("Invalid username or password.")
        except Exception as e:
            print(f"Error logging in: {e}")
        finally:
            self.conn.close()

    # -----------------------
    # Sign Up
    # -----------------------
    def sign_up(self):
        player_id = input("Choose Player ID: ")
        password = input("Create Password: ")
        email = input("Enter Email: ")

        if not player_id or not password or not email:
            print("All fields are required.")
            return

        valid, message = self.is_valid_password(password)
        if not valid:
            print(message)
            return

        if not self.is_valid_email(email):
            print("Invalid email provided.")
            return

        try:
            endpoint = f"/player/register?playerID={player_id}&email={email}&password={password}"
            self.conn.request("POST", endpoint, headers=HEADERS)
            response = self.conn.getresponse()

            if response.status == 200:
                print("Registration successful!")
            else:
                print("Registration failed.")
        except Exception as e:
            print(f"Error registering player: {e}")
        finally:
            self.conn.close()

    # -----------------------
    # Reset Password
    # -----------------------
    def reset_password(self):
        player_id = input("Enter Player ID: ")
        email = input("Enter Email: ")

        try:
            endpoint = f"/player/reset-password?playerID={player_id}&email={email}"
            self.conn.request("POST", endpoint, headers=HEADERS)
            response = self.conn.getresponse()

            if response.status == 200:
                print("Password reset email sent.")
            else:
                print("Password reset failed.")
        except Exception as e:
            print(f"Error resetting password: {e}")
        finally:
            self.conn.close()

    # -----------------------
    # Fetch Ongoing Games
    # -----------------------
    def fetch_ongoing_games(self):
        if not self.authenticated:
            print("Please log in to view ongoing games.")
            return

        games = self.fetch_ongoing_games_common()
        if games:
            print("\n--- Ongoing Games ---")
            for game in games:
                print(f"Game ID: {game['gameID']} | Players: {game['players']} | Turn: {game['turn']}")


    def fetch_ongoing_games_common(self):
        try:
            endpoint = f"/player/games?playerID={self.player_id}"
            self.conn.request("GET", endpoint, headers=HEADERS)
            response = self.conn.getresponse()

            try:
                data = json.loads(response.read().decode())
            except Exception as e:
                data = None

            if response.status == 200 and data and data.get("games"):
                return data.get("games")
            else:
                print("No ongoing games found.")
                return []
            
        except Exception as e:
            print(f"Error fetching games: {e}")
            return []
        finally:
            self.conn.close()

    # -----------------------
    # Bluetooth Scanning and Connecting
    # -----------------------
    async def scan_and_connect_bluetooth(self):
        print("Scanning for Bluetooth devices...")

        devices = await BleakScanner.discover()
        arduino_device = None

        if not devices:
            print("No bluetooth devices found")
            return None

        # Find Arduino based on advertised name
        for device in devices:
            if ARDUINO_NAME == device.name:
                arduino_device = device
                print(f"Found Arduino: {arduino_device.name} ({arduino_device.address})")
                break

        if arduino_device:
            self.client = BleakClient(arduino_device.address)
            try:
                await self.client.connect()
            except:
                print("error connecting to arduino")
                return
            print(f"Connected to {arduino_device.address}")
            
            # List available services and characteristics
            services = await self.client.get_services()
            print(services)
            for service in services:
                print(f"[Service] {service.uuid}")
                for char in service.characteristics:
                    print(f"  [Characteristic] {char.uuid} - {char.properties}")
            # await self.update_characteristics(client)
        else:
            print("Arduino not found. Please ensure it is powered on and in range.")
        return

    async def update_characteristics(self, game):
        # Write to BLE characteristics
        print("updating characteristics of ", self.client.address)
        await self.client.write_gatt_char(SSID_CHAR_UUID, self.ssid.encode('utf-8'))
        print("SSID updated.")

        await self.client.write_gatt_char(PASSWORD_CHAR_UUID, self.wifi_password.encode('utf-8'))
        print("Password updated.")

        await self.client.write_gatt_char(GAMEID_CHAR_UUID, game["gameID"].encode('utf-8'))
        print("Game ID updated.")

        await self.client.write_gatt_char(PLAYERID_CHAR_UUID, self.player_id.encode('utf-8'))
        print("User ID updated.")
        return


    # -----------------------
    # Manage Friends
    # -----------------------
    def manage_friends(self):
        while True:
            print("\n--- Manage Friends ---")
            print("1. View Friends List")
            print("2. Add Friend")
            print("3. Remove Friend")
            print("4. Challenge Friend")
            print("5. Back to Main Menu")

            choice = input("Select an option: ")
            if choice == "1":
                self.view_friends()
            elif choice == "2":
                self.add_friend()
            elif choice == "3":
                self.remove_friend()
            elif choice == "4":
                self.challenge_friend()
            elif choice == "5":
                break
            else:
                print("Invalid option. Try again.")

    # -----------------------
    # View Friends List
    # -----------------------
    def view_friends(self):
        if not self.authenticated:
            print("Please log in to view your friends.")
            return

        try:
            endpoint = f"/player/friends?playerID={self.player_id}"
            self.conn.request("GET", endpoint, headers=HEADERS)
            response = self.conn.getresponse()
            data = json.loads(response.read().decode())

            if response.status == 200:
                self.friends = data.get("friends", [])
                if self.friends:
                    print("\n--- Friends List ---")
                    for friend in self.friends:
                        print(f"- {friend}")
                else:
                    print("No friends found.")
            else:
                print("Failed to fetch friends list.")
        except Exception as e:
            print(f"Error fetching friends: {e}")
        finally:
            self.conn.close()

    # -----------------------
    # Add Friend
    # -----------------------
    def add_friend(self):
        if not self.authenticated:
            print("Please log in to add friends.")
            return

        friend_id = input("Enter Friend's Player ID: ").strip()
        if not friend_id:
            print("Friend ID cannot be empty.")
            return

        if friend_id in self.friends:
            print(f"{friend_id} is already your friend.")
            return

        try:
            endpoint = f"/player/friends/add?playerID={self.player_id}&friendID={friend_id}"
            self.conn.request("POST", endpoint, headers=HEADERS)
            response = self.conn.getresponse()

            if response.status == 200:
                self.friends.append(friend_id)
                print(f"{friend_id} has been added to your friends list.")
            else:
                print("Failed to add friend.")
        except Exception as e:
            print(f"Error adding friend: {e}")
        finally:
            self.conn.close()

    # -----------------------
    # Remove Friend
    # -----------------------
    def remove_friend(self):
        if not self.authenticated:
            print("Please log in to manage friends.")
            return

        if not self.friends:
            print("You have no friends to remove.")
            return

        print("\n--- Remove Friend ---")
        for idx, friend in enumerate(self.friends):
            print(f"{idx + 1}. {friend}")

        try:
            choice = int(input("Select friend to remove (0 to cancel): "))
            if choice == 0:
                return

            friend_id = self.friends[choice - 1]
            confirm = input(f"Remove {friend_id}? (y/n): ").strip().lower()

            if confirm != 'y':
                return

            endpoint = f"/player/friends/remove?playerID={self.player_id}&friendID={friend_id}"
            self.conn.request("POST", endpoint, headers=HEADERS)
            response = self.conn.getresponse()

            if response.status == 200:
                self.friends.remove(friend_id)
                print(f"{friend_id} has been removed.")
            else:
                print("Failed to remove friend.")
        except (ValueError, IndexError):
            print("Invalid selection.")
        except Exception as e:
            print(f"Error removing friend: {e}")
        finally:
            self.conn.close()

    # -----------------------
    # Challenge Friend
    # -----------------------
    def challenge_friend(self):
        if not self.authenticated:
            print("Please log in to challenge friends.")
            return

        if not self.friends:
            print("You have no friends to challenge.")
            return

        print("\n--- Challenge Friend ---")
        for idx, friend in enumerate(self.friends):
            print(f"{idx + 1}. {friend}")

        try:
            choice = int(input("Select friend to challenge (0 to cancel): "))
            if choice == 0:
                return

            friend_id = self.friends[choice - 1]
            endpoint = f"/player/challenge?playerID={self.player_id}&opponentID={friend_id}"
            self.conn.request("POST", endpoint, headers=HEADERS)
            response = self.conn.getresponse()

            if response.status == 200:
                print(f"Challenge sent to {friend_id}.")
            else:
                print("Failed to send challenge.")
        except (ValueError, IndexError):
            print("Invalid selection.")
        except Exception as e:
            print(f"Error challenging friend: {e}")
        finally:
            self.conn.close()


    # -----------------------
    # Manage Games
    # -----------------------
    async def manage_games(self):
        while True:
            print("\n--- Manage Games ---")
            print("1. Create New Game")
            print("2. Join Existing Game")
            print("3. Leave Game")
            print("4. View Ongoing Games")
            print("5. Send Game to Board")
            print("6. Back to Main Menu")

            choice = input("Select an option: ")
            if choice == "1":
                self.create_game()
            elif choice == "2":
                self.join_game()
            elif choice == "3":
                self.leave_game()
            elif choice == "4":
                self.fetch_ongoing_games()
            elif choice == "5":
                await self.send_game_to_board()
            elif choice == "6":
                break
            else:
                print("Invalid option. Try again.")


    # -----------------------
    # Send Game to Board
    # -----------------------
    async def send_game_to_board(self):
        if not self.authenticated:
            print("Please log in to send game to board.")
            return
        
        if not self.client.is_connected:
            print("No board connected. Please connect to a board first.")
            return
        
        self.ssid, self.wifi_password = self.get_connected_wifi_info()
        if not self.ssid or not self.wifi_password:
            print("Must be connected to wifi.")
            return

        games = self.fetch_ongoing_games_common()
        if games:
            print("\n--- Ongoing Games ---")
            for idx, game in enumerate(games):
                print(f"{idx + 1}. Game ID: {game['gameID']}, Opponent: {game['players']}, Turn: {game['turn']}")

            game_choice = input("\nSelect a game to send to the board (Enter number): ")
            
            try:
                selected_game = games[int(game_choice) - 1]
                await self.transmit_game_to_board(selected_game)
            except (IndexError, ValueError):
                print("Invalid selection.")


    # -----------------------
    # Get WiFi info
    # -----------------------
    def get_connected_wifi_info(self):
        try:
            # Get the currently connected network
            current_network_data = subprocess.check_output(['netsh', 'wlan', 'show', 'interfaces']).decode('utf-8').split('\n')
            current_network = [line.split(":")[1][1:-1] for line in current_network_data if "SSID" in line and "BSSID" not in line]

            if current_network:
                ssid = current_network[0]

                # Get the password for the connected network
                results = subprocess.check_output(['netsh', 'wlan', 'show', 'profile', ssid, 'key=clear']).decode('utf-8').split('\n')
                password = [line.split(":")[1][1:-1] for line in results if "Key Content" in line]

                # Return SSID and password
                return ssid, password[0] if password else None
            else:
                return None, None  # No Wi-Fi network connected

        except Exception as e:
            print(f"Error: {e}")
            return None, None  # In case of an error


    # -----------------------
    # Transmit Game to Board via Bluetooth
    # -----------------------
    async def transmit_game_to_board(self, game):
        try:
            await self.update_characteristics(game)
            print(f"Game {game['gameID']} sent to board.")
        except Exception as e:
            print(f"Error sending game to board: {e}")


    # -----------------------
    # Create New Game
    # -----------------------
    def create_game(self):
        if not self.authenticated:
            print("Please log in to create a game.")
            return

        # Step 1: Ask if the player wants to play against AI
        while True:
            print("Would you like to play against AI? (yes/no)")
            ai_choice = input().strip().lower()
            if ai_choice in ["yes", "y", "no", "n"]:
                break
            else:
                print("Invalid input. Please type 'yes' or 'no'.")

        play_against_ai = ai_choice in ["yes", "y"]
        difficulty = None

        # Step 2: If playing against AI, choose difficulty level
        if play_against_ai:
            while True:
                print("Choose AI difficulty level:")
                print("1. Easy")
                print("2. Medium")
                print("3. Hard")
                difficulty_choice = input().strip()

                if difficulty_choice == "1":
                    difficulty = "easy"
                    break
                elif difficulty_choice == "2":
                    difficulty = "medium"
                    break
                elif difficulty_choice == "3":
                    difficulty = "hard"
                    break
                else:
                    print("Invalid choice. Please select 1, 2, or 3.")

        # Step 3: Construct the endpoint
        endpoint = f"/create?playerID={self.player_id}"
        if play_against_ai:
            endpoint += f"&ai=true&difficulty={difficulty}"
        else:
            endpoint += "&ai=false"

        # Step 4: Make the request to create the game
        self.conn.request("POST", endpoint, headers=HEADERS)
        response = self.conn.getresponse()
        data = json.loads(response.read().decode())

        # Step 5: Handle the response
        if response.status == 200:
            game_id = data.get("gameID")
            print(f"Game created successfully! Game ID: {game_id}")
        else:
            print("Failed to create game.")

        # Ensure the connection is closed
        self.conn.close()


    # -----------------------
    # Join Existing Game
    # -----------------------
    def join_game(self):
        if not self.authenticated:
            print("Please log in to join a game.")
            return

        game_id = input("Enter Game ID to join: ").strip()
        if not game_id:
            print("Game ID cannot be empty.")
            return

        endpoint = f"/player/join-game?playerID={self.player_id}&gameID={game_id}"
        try:
            self.conn.request("POST", endpoint, headers=HEADERS)
            response = self.conn.getresponse()
            data = json.loads(response.read().decode())
            print(data)
            if response.status == 200:
                print(f"Successfully joined game {game_id}.")
            else:
                print("Failed to join game.")
        except Exception as e:
            print(f"Error joining game: {e}")
        finally:
            self.conn.close()


    # -----------------------
    # Leave Existing Game
    # -----------------------
    def leave_game(self):
        if not self.authenticated:
            print("Please log in to leave a game.")
            return

        # Fetch ongoing games using the common function
        active_games = self.fetch_ongoing_games_common()
        
        if not active_games:
            print("No active games to leave.")
            return

        # Display the list of active games
        print("Active Games:")
        for idx, game in enumerate(active_games, 1):
            print(f"{idx}. Game ID: {game['gameID']} - Players: {game['players']}")

        # Prompt user to select a game to leave
        try:
            choice = int(input("Enter the number of the game you want to leave: "))
            if choice < 0 or choice > len(active_games):
                print("Invalid selection.")
                return
            
            if choice == 0:
                print("leaving all games")
                return self.leave_all_games()

            else:
                selected_game = active_games[choice - 1]
                game_id = selected_game['gameID']
                print("leaving specific game")
                return self.leave_specific_game(game_id)

        except ValueError:
            print("Invalid input. Please enter a number.")
            return

        
    def leave_all_games(self):
        endpoint = f"/player/end-all-games?playerID={self.player_id}"
        try:
            self.conn.request("POST", endpoint, headers=HEADERS)
            response = self.conn.getresponse()

            # Handle the response
            if response.status == 200:
                print(f"Successfully left games.")
            else:
                data = json.loads(response.read().decode())
                print(f"Failed to leave games: {data.get('error', 'Unknown error')}")
        except Exception as e:
            print(f"Error leaving game: {e}")
        finally:
            self.conn.close()


    def leave_specific_game(self, game_id):
        endpoint = f"/player/end-game?playerID={self.player_id}&gameID={game_id}"
        try:
            self.conn.request("POST", endpoint, headers=HEADERS)
            response = self.conn.getresponse()
            

            # Handle the response
            if response.status == 200:
                print(f"Successfully left game {game_id}.")
            else:
                data = json.loads(response.read().decode())
                print(f"Failed to leave game {game_id}: {data.get('error', 'Unknown error')}")
        except Exception as e:
            print(f"Error leaving game: {e}")
        finally:
            self.conn.close()


    # -----------------------
    # Utilities
    # -----------------------
    def log_out(self):
        self.authenticated = False
        print("Logged out.")

    def is_valid_password(self, password):
        if len(password) < 8 or not re.search(r"[A-Za-z0-9]", password):
            return False, "Password must be at least 8 characters with uppercase, lowercase, and numbers."
        return True, "Password is valid."

    def is_valid_email(self, email):
        return bool(re.match(r"[^@]+@[^@]+\.[^@]+", email))


if __name__ == "__main__":
    app = ChessAppCLI()
    asyncio.run(app.main_menu())
