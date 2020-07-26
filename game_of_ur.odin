package main

import "core:fmt"
import "core:math/rand"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:mem"

// Todo:
// Simulations
//   Multiple simulations at once: multithreading
//   Maybe a bracket tournament between all of the behaviors
// UI
//   Colors?
//   GUI

//
// Game of Ur:
// Board:
// &*&
// ***
// ***
// *#*
//  *
//  *
// &*&
// ***
// 
// & := Second throw
// # := Second throw, and you are safe
// 
// 7 tokens per player
// 4d4; 2 of 4 vertecies are white.
// 
// Rules:
// - Each turn, throw all dice, if dice have a white vertex up, thats +1 to amount of moves, else +0
// - If you land on another player's token while in the warzone, take that other player's token out of the board, they have to go again.
// - You cannot subdivide moves among tokens
// - You can put another token on the board if you wish using your moves.
// - You cannot go on your own token
// - Once a roll you may move any of your tokens on the board with your moves
// 

// Note:
// 
// (0, 0) is offboard (0 X is offboard)
// (1, 3) is onboard such that it's the starting position for the left hand player
// (3, 3) is onboard such that it's the starting position for the right handed player
// (1, 0) is onboard such that it's the top left position for the left hand player
// (3, 0) is onboard such that it's the top right position for the right hand player
// 
board_position :: struct
{
	X: byte,
	Y: byte
}

token :: struct
{
	Position: board_position,
	PlayerID: byte,
	Retired: bool
}

player :: struct
{
	Tokens: []token,
	ID: byte,
}

BoardTiles: [24]byte = [24]byte
{
	1,0,1,
	0,0,0,
	0,0,0,
	0,2,0,
	9,0,9,
	9,0,9,
	1,0,1,
	0,0,0
};
BoardTokens: [24]^token;

config :: struct
{
	TokenCount: u32,
	PlayerAI: [2]bool,
	AI: [2]ai,
	DisablePrint: bool
}

when false
{	
turn_info :: struct
{
	Valid: byte,
	Moves: byte, // 0, 1, 2, 3, 4;
	X: byte,
	Y: byte
}
}
else
{
turn_info :: bit_field
{
	Valid: 1,
	Moves: 3, // 0, 1, 2, 3, 4;
	X: 2,
	Y: 3
}
}

game_state :: struct
{
	Players: [2]player,
	TurnCount: int,
	Turn: byte,
	ExtraTurn: bool,
	TurnHistory: [2][dynamic]turn_info,
}

GetRetiredTokenCount :: proc(Player: player) -> int
{
	Result: int = ---;
	
	RetiredCount: int = 0;
	
	for Token, Index in Player.Tokens
	{
		if(Token.Retired == true)
		{
			RetiredCount += 1;
		}
	}
	
	Result = RetiredCount;
	return Result;
}

PrintGameState :: proc(State: game_state, Config: config, PrintAtX, PrintAtY: i16)
{
	WriteToConsole("Player1's tokens: '1'", 0, 0);
	Player1RetiredCount := GetRetiredTokenCount(State.Players[0]);
	PrintFormatAt(0, 1, " Active: %d Retired: %d", int(Config.TokenCount) - Player1RetiredCount, Player1RetiredCount);
	WriteToConsole("Player2's tokens: '2'", 0, 2);
	Player2RetiredCount := GetRetiredTokenCount(State.Players[1]);
	PrintFormatAt(0, 3, " Active: %d Retired: %d", int(Config.TokenCount) - Player2RetiredCount, Player2RetiredCount);
	fmt.println();
	
	if(State.Turn == 0)
	{
		WriteToConsole("Player1's turn", 0, 5);
	}
	else
	{
		WriteToConsole("Player2's turn", 0, 5);
	}
	fmt.println();
	
	VerticalPosition: rune = 'a';
	
	PrintFormatAt(PrintAtX, PrintAtY, "  1 2 3");
	
	for Y in 0..7
	{
		// SetCursorPosition(PrintAtX, (PrintAtY + 1) + 2*auto_cast(Y));
		switch Y
		{
			case 0:
				PrintFormatAt(PrintAtX, (PrintAtY + 1) + 2*auto_cast(Y), " ┌─┬─┬─┐");
			case 1:
				fallthrough;
			case 2:
				fallthrough;
			case 3:
				PrintFormatAt(PrintAtX, (PrintAtY + 1) + 2*auto_cast(Y), " ├─┼─┼─┤");
			case 4:
				PrintFormatAt(PrintAtX, (PrintAtY + 1) + 2*auto_cast(Y), " └─┼─┼─┘");
			case 5:
				PrintFormatAt(PrintAtX, (PrintAtY + 1) + 2*auto_cast(Y), "   ├─┤");
			case 6:
				PrintFormatAt(PrintAtX, (PrintAtY + 1) + 2*auto_cast(Y), " ┌─┼─┼─┐");
			case 7:
				PrintFormatAt(PrintAtX, (PrintAtY + 1) + 2*auto_cast(Y), " ├─┼─┼─┤");
		}
		
		SetCursorPosition(PrintAtX, (PrintAtY + 1) + 2*auto_cast(Y) + 1);
		fmt.printf((Y != 4 && Y != 5) ? "%c│" : "%c ", VerticalPosition);
		VerticalPosition += 1;
		for X in 0..2
		{
			Tile: rune;
			Token: ^token = BoardTokens[Y*3 + X];
			if(Token == nil)
			{
				switch(BoardTiles[Y*3 + X])
				{
					case 0:
						Tile = ' ';
					case 1:
						Tile = '¤';
					case 2:
						Tile = '¤';
					case 9:
						Tile = ' ';
				}
				fmt.printf("%c", Tile);
				fmt.printf((BoardTiles[Y*3 + X] == 9 && X == 2) ? " " : "│");
			}
			else
			{
				fmt.printf("%c│", Token.PlayerID == 0 ? '1' : '2');
			}
		}
		
		if(Y == 7)
		{
			SetCursorPosition(PrintAtX, (PrintAtY + 1) + 2*auto_cast(Y) + 2);
			fmt.printf(" └─┴─┴─┘\n");
		}
	}
	
	PrintTurnHistory(State.TurnHistory, 0, 6, 8);
	PrintFormatAt(0, 16, "% 4d", State.TurnCount);
}

InitializePlayers :: proc(TokenCount: u32) -> [2]player
{
	Result : [2]player;
	
	Result[0].ID = 0;
	Result[0].Tokens = make([]token, TokenCount);
	for Token, Index in Result[0].Tokens
	{
		Result[0].Tokens[Index].PlayerID = 0;
	}
	
	Result[1].ID = 1;
	Result[1].Tokens = make([]token, TokenCount);
	for Token, Index in Result[1].Tokens
	{
		Result[1].Tokens[Index].PlayerID = 1;
	}
	
	return Result;
}

DeletePlayers :: proc(Players: [2]player)
{
	delete(Players[0].Tokens);
	delete(Players[1].Tokens);
}

InitializeGameBoard :: proc()
{
	BoardTokens = {};
}

DeleteBoard :: proc()
{
	BoardTokens = {};
}

InitializeGame :: proc(TokenCount: u32) -> game_state
{
	Result: game_state = {};
	
	InitializeGameBoard();
	Result.Players = InitializePlayers(TokenCount);
	Result.TurnCount = 0;
	
	return Result;
}

// Note:
// Return Byte special cases
//     9 = Can go off the board safely, retiring the token
//   255 = This token cannot move this many spaces because of obstruction or
//          more moves than needed to retire token
BoardTileAtMovesAhead :: proc(Token: token, MoveCount: byte) -> (byte, ^token, board_position)
{
	ResultType: byte;
	ResultToken: ^token;
	
	Distance : byte = 0;
	WalkPosition : board_position = Token.Position;
	for
	{
		if(Distance == MoveCount)
		{
			if(WalkPosition.X > 0)
			{ // Note: Is on board
				ResultType = BoardTiles[WalkPosition.Y*3 + (WalkPosition.X - 1)];
				ResultToken = BoardTokens[WalkPosition.Y*3 + (WalkPosition.X - 1)];
			}
			else
			{
				ResultType = 255;
				ResultToken = nil;
			}
			
			break;
		}
		
		if(WalkPosition.X == 1 && WalkPosition.Y <= 3 ||
		   WalkPosition.X == 3 && WalkPosition.Y <= 3)
		{
			// Note: Player specific side starting lane
			if(WalkPosition.Y == 0)
			{
				WalkPosition.X = 2;
			}
			else
			{
				WalkPosition.Y -= 1;
			}
			
			Distance += 1;
		}
		else if(WalkPosition.X == 2)
		{
			if(WalkPosition.Y == 7)
			{
				// Note: crossroad from Middle lane to outgoing lanes off the board
				WalkPosition.X = Token.PlayerID == 0 ? 1 : 3;
			}
			else
			{
				WalkPosition.Y += 1;
			}
			
			Distance += 1;
		}
		else if(WalkPosition.X == 1 && WalkPosition.Y >= 6 ||
				WalkPosition.X == 3 && WalkPosition.Y >= 6)
		{
			// Note: On either player specific side, on the way out off the board
			if(WalkPosition.Y == 6)
			{
				ResultType = (Distance == MoveCount - 1) ? 9 : 255;
				WalkPosition.Y = 5;
				ResultToken = nil;
				break;
			}
			else
			{
				WalkPosition.Y -= 1;
				Distance += 1;
			}
		}
		else if(WalkPosition.X == 0)
		{
			// Note: Not on the board yet
			WalkPosition.X = (Token.PlayerID == 0) ? 1 : 3;
			WalkPosition.Y = 3;
			Distance += 1;
		}
		else
		{
			fmt.println(Token, WalkPosition);
			panic("AHHHHH");
		}
	}
	
	return ResultType, ResultToken, WalkPosition;
}

PositionAtMoveCountIsFree :: proc(Token: token, MoveCount: byte) -> (bool, board_position)
{
	Result: bool = true;

	TileType: byte;
	TileToken: ^token;
	TilePosition: board_position;
	TileType, TileToken, TilePosition = BoardTileAtMovesAhead(Token, MoveCount);
	
	if(TileToken != nil && TileToken.PlayerID == Token.PlayerID)
	{
		Result = false;
	}
	else if(TileToken != nil && (TileToken.PlayerID != Token.PlayerID) &&
	        TileType == 2)
	{
		Result = false;
	}
	else if(TileType == 255)
	{
		Result = false;
	}
	
	return Result, TilePosition;
}

// Note: Alright so this is actually going to return an array, each index in the array is a corresponding index to
//       the tokens of the player
GetPotentialMoves :: proc(Player: player, MoveCount: byte) -> []board_position
{
	Result: []board_position;
	Result = make([]board_position, len(Player.Tokens));
	
	HasPrintedHomeMove: bool = false;
	
	CanMove: bool;
	Position: board_position;
	Token: token;
	for Index in 0..len(Player.Tokens) - 1
	{
		Token = Player.Tokens[Index];
		if(Token.Retired == true)
		{
			continue;
		}
		
		CanMove, Position = PositionAtMoveCountIsFree(Token, MoveCount);
		if(CanMove)
		{
			if(Token.Position.X > 0)
			{ // Note: It's on the board
				Result[Index] = Position;
			}
			else if(HasPrintedHomeMove == false)
			{
				Result[Index] = Position;
				
				HasPrintedHomeMove = true;
			}
		}
	}
	
	return Result;
}

PrintPotentialMoves :: proc(Player: player, MoveCount: byte, PotentialMoves: []board_position) -> int
{
	ValidOptions: [dynamic]byte;
	defer delete(ValidOptions);
	
	for Index in 0..len(PotentialMoves) - 1
	{
		Token: token = Player.Tokens[Index];
		if(Token.Retired == true)
		{
			continue;
		}
		
		Position: board_position = PotentialMoves[Index];
		if(Position.X == 0)
		{
			// println("Token ", Index, " cannot move");
		}
		else
		{
			append(&ValidOptions, byte(Index));
			LetterPosition: rune = 'a' + (rune)(Position.Y);
			if(Token.Position.X == 0)
			{
				fmt.printf("Token %d can move onto the board at %c%d\n", Index + 1, LetterPosition, Position.X);
			}
			else if((Position.X == 1 || Position.Y == 3) &&
			        Position.Y == 5)
			{
				fmt.printf("Token %d can retire\n", Index + 1);
			}
			else
			{
				fmt.printf("Token %d can move to %c%d\n", Index + 1, LetterPosition, Position.X);
			}
		}
	}
	
	for _, Index in ValidOptions
	{
		ValidOptions[Index] += 1;
	}
	
	fmt.println("Valid Options: ", ValidOptions);
	
	return len(ValidOptions);
}

GetTileTypeFromBoard :: proc(Position: board_position) -> byte
{
	Result: byte;
	
	Result = BoardTiles[Position.Y*3 + (Position.X - 1)];
	
	return Result;
}

// Todo: Do we want this to take a board_position instead? Do we care enough?
GetTokenFromBoard :: proc(Position: board_position) -> ^token
{
	Result: ^token;
	
	Result = BoardTokens[Position.Y*3 + (Position.X - 1)];
	
	return Result;
}

// Note: Option is corresponding to the token index
MakeMove :: proc(State: ^game_state, MoveCount: byte, Option: byte) -> bool
{
	Result: bool = true;
	
	Player: player = State.Players[State.Turn];
	PotentialMoves: []board_position = GetPotentialMoves(Player, MoveCount);
	defer delete(PotentialMoves);
	
	if(Option < 0 ||
	   Option > auto_cast(len(PotentialMoves) - 1))
	{
		Result = false;
	}
	else if(PotentialMoves[Option].X > 0)
	{
		Position: board_position = PotentialMoves[Option];
		Token: ^token = &Player.Tokens[Option];
		TileToken: ^token = BoardTokens[Position.Y*3 + (Position.X - 1)];
		
		if(TileToken != nil && TileToken.PlayerID != Token.PlayerID)
		{
			TileToken.Position.X = 0;
			TileToken.Position.Y = 0;
		}
		if(Token.Position.X > 0)
		{
			BoardTokens[Token.Position.Y*3 + (Token.Position.X - 1)] = nil;
		}
		if(Position.Y == 5 && (Position.X == 1 || Position.X == 3))
		{
			Token.Position.X = Position.X;
			Token.Position.Y = Position.Y;
			Token.Retired = true;
		}
		else
		{
			Token.Position.X = Position.X;
			Token.Position.Y = Position.Y;
			BoardTokens[Position.Y*3 + (Position.X - 1)] = Token;
		}
		
		TileType: byte = GetTileTypeFromBoard(Position);
		if(TileType == 1 ||
		   TileType == 2)
		{
			State.ExtraTurn = true;
		}
	}
	else
	{
		Result = false;
	}
	
	return Result;
}

GetRandomDieOutput :: proc() -> byte
{
	Result: byte;
	
	// Note:
	// Possibilities = 2^4 = 16
	// 0 -> 1/16
	// 1 -> 4/16
	// 2 -> 6/16
	// 3 -> 4/16
	// 4 -> 1/16
	
	Random := rand.float32();
	
	assert(Random > 0.0);
	
	Chance : f32 = 1.0/16.0;
	if(Random < Chance)
	{
		Result = 0;
		return Result;
	}
	
	Chance = 5.0/16.0;
	if(Random < Chance)
	{
		Result = 1;
		return Result;
	}
	
	Chance = 11.0/16.0;
	if(Random < Chance)
	{
		Result = 2;
		return Result;
	}

	Chance = 15.0/16.0;
	if(Random < Chance)
	{
		Result = 3;
		return Result;
	}
	
	Chance = 1.0;
	if(Random <= Chance)
	{
		Result = 4;
		return Result;
	}
	
	fmt.println(Random);
	// panic("We had a problem with the dice roll..."); // Note: hmmm
	
	return Result;
}

BoolFromYNString :: proc(Input: []byte) -> bool
{
	Result: bool = false;
	
	if(Input[0] == 'y' ||
	   Input[0] == 'Y')
	{
		Result = true;
	}
	
	return Result;
}

WaitForInput :: proc()
{
	Buffer: [4096]byte;
	ReadFromConsole(Buffer[:], 4096);
}

PromptAIBehavior :: proc(AI: ^ai)
{
	Buffer: [256]byte;
	
	fmt.println("(0) Borg Perfection (Very Unimplemented)");
	fmt.println("(1) Random");
	fmt.println("(2) Aggressive");
	fmt.println("(3) Defensive");
	fmt.println("(4) Economic");
	fmt.println("(5) Racer");
	fmt.println("(23) Aggressive Dominant; Defensive Recessive");
	fmt.println("(24) Aggressive Dominant; Economic Recessive");
	fmt.println("(25) Aggressive Dominant; Racer Recessive");
	fmt.println("(32) Defensive Dominant; Aggressive Recessive");
	fmt.println("(34) Defensive Dominant; Economic Recessive");
	fmt.println("(35) Defensive Dominant; Racer Recessive");
	fmt.println("(42) Economic Dominant; Aggressive Recessive");
	fmt.println("(43) Economic Dominant; Defensive Recessive");
	fmt.println("(45) Economic Dominant; Racer Recessive");
	// fmt.println("(99) Choose a random behavior!");
	
	fmt.printf("> ");
	ReadFromConsole(Buffer[:], 256);
	EnumValue := strconv.atoi(string(Buffer[:]));
	fmt.println("AI behavior enum value:", EnumValue);
	
	/*
	// Random AI stuff
	if(EnumValue == 99)
	{
		RandomBehavior := 99;
		for RandomBehavior == 99
		{
			RandomBehavior = int(rand.int31())%len(ai_behavior);
		}
		
		EnumValue = ai_behavior[RandomBehavior];
	}
	*/
	
	AI.Behavior = ai_behavior(EnumValue);
}

ReadFromConsole :: proc(Buffer: []byte, BufferLength: int) -> (int, os.Errno)
{
	mem.zero(&Buffer[0], BufferLength);
	
	Character: [1]byte;
	Index: int;
	Input, Error := os.read(os.stdin, Character[:]);
	for Error == 0
	{
		if(Character[0] == '\n')
		{
			break;
		}
		else
		{
			if(Character[0] != '\r')
			{
				Buffer[Index] = Character[0];
				Index += 1;
			}
		}

		Input, Error = os.read(os.stdin, Character[:]);
	}
	
	return Index, Error;
}

PromptConfig :: proc() -> config
{
	Result: config = {};
	
	Buffer: [256]byte;
	
	fmt.println();
	fmt.println("Config:");
	
	fmt.printf("Amount of Tokens (Single digits) (7): ");
	ReadFromConsole(Buffer[:], 256);
	Result.TokenCount = auto_cast strconv.atoi(string(Buffer[:]));
	
	Result.PlayerAI[0] = false;
	fmt.printf("Player 1 is AI?(y/n): ");
	ReadFromConsole(Buffer[:], 256);
	Result.PlayerAI[0] = BoolFromYNString(Buffer[:]);
	
	if(Result.PlayerAI[0] == true)
	{
		fmt.println("Player 1 AI behavior");
		PromptAIBehavior(&Result.AI[0]);
	}
	
	Result.PlayerAI[1] = false;
	fmt.printf("Player 2 is AI?(y/n): ");
	ReadFromConsole(Buffer[:], 256);
	Result.PlayerAI[1] = BoolFromYNString(Buffer[:]);

	if(Result.PlayerAI[1] == true)
	{
		fmt.println("Player 2 AI behavior");
		PromptAIBehavior(&Result.AI[1]);
	}
	
	fmt.println();
	fmt.println("Config:");
	fmt.println("Tokens:", Result.TokenCount);
	if(Result.PlayerAI[0])
	{
		fmt.println("Player1 is: AI, With behavior:", Result.AI[0].Behavior);
	}
	else
	{
		fmt.println("Player1 is: Human");
	}
	if(Result.PlayerAI[1])
	{
		fmt.println("Player2 is: AI, With behavior:", Result.AI[1].Behavior);
	}
	else
	{
		fmt.println("Player2 is: Human");
	}
	
	return Result;
}

DefaultConfig :: proc() -> config
{
	Result: config = {};
	
	Result.TokenCount = 7;
	Result.PlayerAI[0] = false;
	Result.PlayerAI[1] = true;
	Result.AI[1].Behavior = AIBehavior_Defensive;
	Result.DisablePrint = false;
	
	return Result;
}

PlayerHasWon :: proc(Player: player) -> bool
{
	Result: bool = true;
	
	for Token, Index in Player.Tokens
	{
		if(Token.Retired == false)
		{
			Result = false;
			break;
		}
	}
	
	return Result;
}

RunAIGames :: proc(Config: config, GameAmount: int, DeleteAndWait: bool) -> (int, int)
{
	State: game_state;
	
	WinCount: [2]int = {};
	MinTurns: int = 0x7FFFFFFF;
	MaxTurns: int = 0;
	TurnAssemblage: [dynamic]int;
	defer delete(TurnAssemblage);
	
	for GameCount in 0..GameAmount - 1
	{		
		if(!Config.DisablePrint)
		{
			ClearConsole();
		}
		
		State = InitializeGame(Config.TokenCount);
		defer delete(State.TurnHistory[0]);
		defer delete(State.TurnHistory[1]);
		
		SecondPlayersTurn: bool = false;
		for
		{
			if(!Config.DisablePrint)
			{
				// ClearConsole();
				PrintGameState(State, Config, 26, 0);
			}
			
			MoveCount := GetRandomDieOutput();
			
			MovePosition: board_position = {0, 0};
			if(MoveCount > 0)
			{
				if(!Config.DisablePrint)
				{
					// println("Moves:", MoveCount);
				}
				MovePosition = AIMakeMove(&State, MoveCount, Config);
			}
			else
			{
				if(!Config.DisablePrint)
				{
					// println("Rolled 0...");
				}
			}
			
			TurnInfo: turn_info = {};
			
			if(len(State.TurnHistory[0]) == 0 ||
			   len(State.TurnHistory[1]) == 0)
			{
				append(&State.TurnHistory[0], TurnInfo);
				append(&State.TurnHistory[1], TurnInfo);
			}
			
			TurnHistoryLength := len(State.TurnHistory[State.Turn]);
			if(int(State.TurnHistory[State.Turn][TurnHistoryLength - 1].Valid) == 1)
			{
				TurnInfo: turn_info = {};
				append(&State.TurnHistory[0], TurnInfo);
				append(&State.TurnHistory[1], TurnInfo);
			}
			TurnHistoryLength = len(State.TurnHistory[State.Turn]);
			
			TurnInfo.Valid = 1;
			TurnInfo.Moves = MoveCount;
			TurnInfo.X = MovePosition.X;
			TurnInfo.Y = MovePosition.Y;
			
			State.TurnHistory[State.Turn][TurnHistoryLength - 1] = TurnInfo;
			
			if(PlayerHasWon(State.Players[State.Turn]))
			{
				if(!Config.DisablePrint)
				{
					/*
					println();
					println();
					println("Player", State.Turn + 1, "has won!");
					println("Game finished in", State.TurnCount, "turns!");
					println();
					println();
					ClearConsole();
					*/
				}
				
				WinCount[State.Turn] += 1;
				append(&TurnAssemblage, State.TurnCount);
				
				break;
			}
			
			if(State.ExtraTurn == false)
			{
				State.Turn = (State.Turn + 1)%2;
				if(SecondPlayersTurn == true)
				{
					State.TurnCount += 1;
				}
				SecondPlayersTurn = !SecondPlayersTurn;
			}
			
			State.ExtraTurn = false;
		}
		
		MinTurns = (State.TurnCount < MinTurns) ? State.TurnCount : MinTurns;
		MaxTurns = (State.TurnCount > MaxTurns) ? State.TurnCount : MaxTurns;
		
		DeletePlayers(State.Players);
		// DeleteBoard(); // Note: not needed anymore I think
		
		if(GameCount%128 == 0)
		{
			if(Config.DisablePrint)
			{
				fmt.printf("\rSimulating: %f%%", f32(GameCount)/f32(GameAmount)*100);
			}
		}
	}
	
	
	if(DeleteAndWait)
	{
		ClearConsole();
	}
	
	fmt.println("\n///////////////////////////////////////////////////");
	TotalGames := WinCount[0] + WinCount[1];
	fmt.println("Total games:", TotalGames);
	fmt.println("Total games:", TotalGames);
	fmt.println("Player1 won", WinCount[0], "times, player2", WinCount[1], "times");
	fmt.println("           ", f32(WinCount[0])/f32(TotalGames)*100.0, "%             ", f32(WinCount[1])/f32(TotalGames)*100.0, "%");
	
	TotalTurns : int = 0;
	for Turns in TurnAssemblage
	{
		TotalTurns += Turns;
	}
	
	fmt.println("Average turns per game", f32(TotalTurns)/f32(len(TurnAssemblage)));
	fmt.println("Minimum turns:", MinTurns, "; Maximum turns:", MaxTurns);
	fmt.println("///////////////////////////////////////////////////");
	fmt.println("Press Enter");
	if(DeleteAndWait)
	{
		WaitForInput();
	}
	
	return WinCount[0], WinCount[1];
}

EachToEachBehaviorAISimulation :: proc(Config: ^config, GameAmount: int)
{
	Output: strings.Builder = strings.make_builder();
	defer delete(Output.buf);
	
	SetOfBehaviors: []ai_behavior = 
	{
		// AIBehavior_Borg,
		AIBehavior_Random,
		AIBehavior_Aggresive,
		AIBehavior_Defensive,
		AIBehavior_Economic,
		AIBehavior_Racer,
		AIBehavior_AggressiveDefensive,
		AIBehavior_AggressiveEconomic,
		AIBehavior_AggressiveRacer,
		AIBehavior_DefensiveAggressive,
		AIBehavior_DefensiveEconomic,
		AIBehavior_DefensiveRacer,
		AIBehavior_EconomicAggressive,
		AIBehavior_EconomicDefensive,
		AIBehavior_EconomicRacer,
	};
	
	Config.DisablePrint = true;
	for Player1Behavior in SetOfBehaviors
	{
		for Player2Behavior in SetOfBehaviors
		{
			Config.AI[0].Behavior = Player1Behavior;
			Config.AI[1].Behavior = Player2Behavior;

			fmt.println("AI 1 behavior", Config.AI[0].Behavior);
			fmt.println("AI 2 behavior", Config.AI[1].Behavior);
			
			Player1Wins, Player2Wins := RunAIGames(Config^, GameAmount, false);
			
			fmt.sbprintf(&Output, "P1 %s, P2 %s\nPlayer 1,%d\nPlayer 2,%d\n", Player1Behavior, Player2Behavior, Player1Wins, Player2Wins);
			
			fmt.println();
			fmt.println();
		}
	}
	
	Handle, Error := os.open("data.csv", os.O_WRONLY|os.O_CREATE);
	if(Error == os.ERROR_NONE)
	{
		os.write_string(Handle, string(Output.buf[:]));
		os.close(Handle);
	}
	else
	{
		fmt.println("ERROR:", Error);
	}
	
	Config.DisablePrint = false;
	WaitForInput();
}

PrintTurnHistory :: proc(TurnHistory: [2][dynamic]turn_info, X, Y: i16, HistoryCount_: int)
{
	HistoryLength: int = len(TurnHistory[0]);
	PrintFormatAt(X, Y,     "    ┌────┬────┐");
	PrintFormatAt(X, Y + 1, "    │Pla1│Pla2│");
	PrintFormatAt(X, Y + 2, "    ├─┬──┼─┬──┤");
	Line: i16 = 3;
   
   HistoryCount := HistoryCount_;
	if(HistoryCount == 0)
	{
		HistoryCount = HistoryLength;
	}
	for PastTurn: = HistoryCount;  PastTurn > 0; PastTurn -= 1
	{
		if(HistoryLength - PastTurn >= 0)
		{
			Info1: turn_info = TurnHistory[0][HistoryLength - PastTurn];
			if(int(Info1.Valid) == 1)
			{
				if(int(Info1.Moves) == 0)
				{
					PrintFormatAt(X, Y + Line, "    │%d│  │", Info1.Moves);
				}
				else
				{
					PrintFormatAt(X, Y + Line, "    │%d│%c%d│", Info1.Moves, byte(Info1.Y) + 'a', Info1.X);
				}
			}
			else
			{
				PrintFormatAt(X, Y + Line, "    │ │  │");
			}
			
			Info2: turn_info = TurnHistory[1][HistoryLength - PastTurn];
			if(int(Info2.Valid) == 1)
			{
				if(int(Info2.Moves) == 0)
				{
					PrintFormatAt(X + 10, Y + Line, "%d│  │", Info2.Moves);
				}
				else
				{
					PrintFormatAt(X + 10, Y + Line, "%d│%c%d│", Info2.Moves, byte(Info2.Y) + 'a', Info2.X);
				}
			}
			else
			{
				PrintFormatAt(X + 10, Y + Line, " │  │");
			}

			
		}
		else
		{
			PrintFormatAt(X, Y + Line, "    │ │  │ │  │");
		}
		
		Line += 1;
	}
	
	PrintFormatAt(X, Y + Line, "    └─┴──┴─┴──┘");
}

main :: proc()
{
	// println("Oh boy, Here I go programmin' again!");
	// println();
	
	PreviousCodePage: = GetConsoleCodePage();
	SetConsoleCodePage(65001);
	
	Config := DefaultConfig();
	State: game_state;
	
	Buffer: [256]byte;
	
	Choice: int = -1;
	InMenu: bool = true;
	WantsToQuit: bool = false;
	for
	{
		for Choice < 0
		{
			ClearConsole();
			fmt.println("The Royal Game of Ur");
			fmt.println("                     (everything is still in progress)");
			fmt.println("                     (may the deities have mercy on your soul)");
			fmt.println("(1): Play The Game");
			fmt.println("(2): Configure");
			fmt.println("(3): Run AI Games");
			fmt.println("(4): Simulate N to N AI Behavior Analysis");
			fmt.println("(0): Exit Game");
			
			for
			{
				fmt.printf("> ");
				ReadFromConsole(Buffer[:], 256);
				Choice = strconv.atoi(string(Buffer[:]));
				if(Choice >= 0 && Choice <= 6)
				{
					fmt.println();
					break;
				}
			}
		}
		
		if Choice == 0
		{
			fmt.println("Exiting Game");
			break;
		}
		else if(Choice == 2)
		{
			Config = PromptConfig();
		}
		else if(Choice == 3)
		{
			fmt.printf("Amount of games: ");
			ReadFromConsole(Buffer[:], 256);
			GameAmount := strconv.atoi(string(Buffer[:]));
			
			fmt.println("Player 1 AI behavior");
			PromptAIBehavior(&Config.AI[0]);
			fmt.println();
			fmt.println("Player 2 AI behavior");
			PromptAIBehavior(&Config.AI[1]);

			fmt.println("Disable printing?(y/n)");
			fmt.printf("> ");
			ReadFromConsole(Buffer[:], 256);
			Config.DisablePrint = (Buffer[0] == 'y') ? true : false;
			
			ClearConsole();
			RunAIGames(Config, GameAmount, true);
			
			Config.DisablePrint = false;
		}
		else if(Choice == 4)
		{
			fmt.printf("Amount of games: ");
			ReadFromConsole(Buffer[:], 256);
			GameAmount := strconv.atoi(string(Buffer[:]));
			EachToEachBehaviorAISimulation(&Config, GameAmount);
		}
		else if(Choice == 1)
		{
			WantsToQuit = false;
			
			State = InitializeGame(Config.TokenCount);
			defer delete(State.TurnHistory[0]);
			defer delete(State.TurnHistory[1]);
		
			SecondPlayersTurn: bool = false;
			for WantsToQuit == false
			{
				if(!Config.DisablePrint)
				{
					ClearConsole();
					PrintGameState(State, Config, 26, 0);
				}
				
				MoveCount := GetRandomDieOutput();
				
				MovePosition: board_position = {};
				
				if(MoveCount > 0)
				{
					switch(Config.PlayerAI[State.Turn])
					{
						case true:
							MovePosition = AIMakeMove(&State, MoveCount, Config);
						case false:
							fmt.println("Moves:", MoveCount);
							PotentialMoves := GetPotentialMoves(State.Players[State.Turn], MoveCount);
							OptionCount := PrintPotentialMoves(State.Players[State.Turn], MoveCount, PotentialMoves[:]);
							
							if(OptionCount > 0)
							{
								fmt.printf("> ");
								ReadFromConsole(Buffer[:], 256);
								if(Buffer[0] == 'q' || Buffer[0] == 'e')
								{
									WantsToQuit = true;
									break;
								}
								Option := byte(strconv.atoi(string(Buffer[:]))) - 1;

								for !MakeMove(&State, MoveCount, Option)
								{
									fmt.println("Invalid Move, try again");
									fmt.printf("> ");
									ReadFromConsole(Buffer[:], 256);
									if(Buffer[0] == 'q' || Buffer[0] == 'e')
									{
										WantsToQuit = true;
										break;
									}
									Option = byte(strconv.atoi(string(Buffer[:]))) - 1;
								}
								
								MovePosition = PotentialMoves[Option];
							}
							else
							{
								fmt.println("You cannot make any valid moves");
							}
					}
				}
				else
				{
					if(!Config.DisablePrint)
					{
						fmt.println("Rolled 0...");
					}
				}

				TurnInfo: turn_info = {};
				
				if(len(State.TurnHistory[0]) == 0 ||
				   len(State.TurnHistory[1]) == 0)
				{
					append(&State.TurnHistory[0], TurnInfo);
					append(&State.TurnHistory[1], TurnInfo);
				}
				
				TurnHistoryLength := len(State.TurnHistory[State.Turn]);
				if(int(State.TurnHistory[State.Turn][TurnHistoryLength - 1].Valid) == 1)
				{
					TurnInfo: turn_info = {};
					append(&State.TurnHistory[0], TurnInfo);
					append(&State.TurnHistory[1], TurnInfo);
				}
				TurnHistoryLength = len(State.TurnHistory[State.Turn]);
				
				TurnInfo.Valid = 1;
				TurnInfo.Moves = MoveCount;
				TurnInfo.X = MovePosition.X;
				TurnInfo.Y = MovePosition.Y;
				
				State.TurnHistory[State.Turn][TurnHistoryLength - 1] = TurnInfo;
				
				if(PlayerHasWon(State.Players[State.Turn]))
				{
					if(!Config.DisablePrint)
					{
						fmt.println();
						fmt.println();
						fmt.println("Player", State.Turn + 1, "has won!");
						fmt.println("Game finished in", State.TurnCount, "turns!");
						fmt.println();
						fmt.println();

						DeletePlayers(State.Players);
						// DeleteBoard(State.Board); // Note: not needed anymore
						fmt.println("Press Enter To Exit: Press h to view turn history");
						ReadFromConsole(Buffer[:], 256);
						
						if(Buffer[0] == 'h')
						{
							PrintTurnHistory(State.TurnHistory, 38, 0, 0);
						}
						ReadFromConsole(Buffer[:], 256);
						
						ClearConsole();
					}
					
					break;
				}
				
				if(State.ExtraTurn == false)
				{
					State.Turn = (State.Turn + 1)%2;
					if(SecondPlayersTurn == true)
					{
						State.TurnCount += 1;
					}
					SecondPlayersTurn = !SecondPlayersTurn;
				}
				
				State.ExtraTurn = false;
			}
		}
		
		Choice = -1;
	}
	
	SetConsoleCodePage(PreviousCodePage);
}


















