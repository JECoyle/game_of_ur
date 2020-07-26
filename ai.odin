package main

import "core:fmt"
import "core:math"
import "core:math/rand"

// Strategies:
// - Random
//    Completely random from whatever moves it can make
// - Aggressive
//    If there's an enemy token it can knock off, do it, otherwise random
// - Economic
//    If a token can land on a free slot, do it, otherwise random
// - Defensive
//    If an enemy token(s) are close to exiting their gate lane, prefer to put another token into play or any move that doesn't put our own token into harms way
//    If there's a token in the war lane
//        If there's an enemy token ahead of it, prefer not to pass it
//        If an enemy is behind or at their gate, prefer to go into the safe slot, run for the citidel lane
// - Racer
//    If you have a token on the board already, Just go straight for the end, otherwise just put one on the board
// - Combination
//    - Aggressive Dominant, Economic recessive
//    - Economic Dominant, Aggressive recessive
//    - Economic Dominant, Defensive recessive
//    - etc...?
//    Racer dominant, anything else recessive doesn't make sense
//    Also... AggressiveRacer doesn't make too much sense either
// - Perfect
//    Makes choices based off the choice's branch win percentage
//

using ai_behavior :: enum
{
	AIBehavior_Borg = 0,
	AIBehavior_Random = 1,
	AIBehavior_Aggresive = 2,
	AIBehavior_Defensive = 3,
	AIBehavior_Economic = 4,
	AIBehavior_Racer = 5,
	AIBehavior_AggressiveDefensive = 23,
	AIBehavior_AggressiveEconomic = 24, 
	AIBehavior_AggressiveRacer = 25,
	AIBehavior_DefensiveAggressive = 32,
	AIBehavior_DefensiveEconomic = 34,
	AIBehavior_DefensiveRacer = 35,
	AIBehavior_EconomicAggressive = 42,
	AIBehavior_EconomicDefensive = 43,
	AIBehavior_EconomicRacer = 45,
	AIBehavior_ChooseRandomBehavior = 99,
};

ai :: struct
{
	Behavior: ai_behavior,
}

AIDetermineAggressiveChoice :: proc(PotentialMoves: []board_position, Options: []byte) -> (int, bool)
{
	Result: int = -1;
	HappyWithMove: bool = false;
	
	for TokenIndex, Index in Options
	{
		Position := PotentialMoves[TokenIndex];
		TileToken: ^token = GetTokenFromBoard(Position);
		
		// Note: This Tile's Token we know to be an enemies, and we _can_ take it
		if(TileToken != nil)
		{
			HappyWithMove = true;
			Result = Index;
			break;
		}
	}
	
	// Todo: Take away the need for HappyWithMove by returning -1?
	if(Result == -1)
	{
		Result = int(rand.int31())%len(Options);
	}
	
	return Result, HappyWithMove;
}

AIDetermineEconomicChoice :: proc(PotentialMoves: []board_position, Options: []byte) -> (int, bool)
{
	Result: int = -1;
	HappyWithMove: bool = false;
	
	for TokenIndex, Index in Options
	{
		Position := PotentialMoves[TokenIndex];
		TileType: byte = GetTileTypeFromBoard(Position);
		
		if(TileType == 1 || TileType == 2)
		{
			HappyWithMove = true;
			Result = Index;
			break;
		}
	}
	
	// Todo: Take away the need for HappyWithMove by returning -1?
	if(Result == -1)
	{
		Result = int(rand.int31())%len(Options);
	}
	
	return Result, HappyWithMove;
}

AIDetermineEconomicAggressiveChoice :: proc(PotentialMoves: []board_position, Options: []byte) -> int
{
	Result: int = -1;
	
	for TokenIndex, Index in Options
	{
		Position := PotentialMoves[TokenIndex];
		TileType: byte = GetTileTypeFromBoard(Position);
		
		if(TileType == 1 || TileType == 2)
		{
			Result = Index;
			break;
		}
	}
	
	// Todo: Take away the need for HappyWithMove by returning -1?
	if(Result == -1)
	{
		for TokenIndex, Index in Options
		{
			Position := PotentialMoves[TokenIndex];
			TileToken: ^token = GetTokenFromBoard(Position);
			
			// Note: This Tile's Token we know to be an enemies, and we _can_ take it
			if(TileToken != nil)
			{
				Result = Index;
				break;
			}
		}
		
		if(Result == -1)
		{
			Result = int(rand.int31())%len(Options);
		}
	}
	
	return Result;
}

GetEnemiesPositions :: proc(Player: player) -> [dynamic]board_position
{
	Result: [dynamic]board_position;
	
	for Token, Index in BoardTokens
	{
		if(Token != nil && Token.PlayerID != Player.ID)
		{
			append(&Result, Token.Position);
		}
	}
	
	return Result;
}

WalkFrom :: proc(Position: board_position, MoveCount: byte, Player: player) -> board_position
{ // Todo: Put this in main game_of_ur.odin
	Result: board_position;
	
	PlayersSide: byte = Player.ID == 0 ? 1 : 3;
	
	Distance: byte = 0;
	WalkPosition: board_position = Position;
	for
	{
		if(Distance == MoveCount)
		{
			Result = WalkPosition;
			
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
				WalkPosition.X = PlayersSide;
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
				WalkPosition.Y = 5;
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
			WalkPosition.X = PlayersSide;
			WalkPosition.Y = 3;
			Distance += 1;
		}
		else
		{
			panic("AHHHHH");
		}
	}

	return Result;
}

AIDetermineDefensiveChoice :: proc(PotentialMoves: []board_position, Options: []byte, Player: player, MoveCount: byte) -> (int, bool)
{
	Result: int = -1;
	HappyWithMove: bool = false;
	
	EnemyTokens: [dynamic]board_position = GetEnemiesPositions(Player);
	defer delete(EnemyTokens);
	
	ChanceOfRolling: [5]f32;
	ChanceOfRolling[0] = 1.0/16.0;
	ChanceOfRolling[1] = 4.0/16.0;
	ChanceOfRolling[2] = 6.0/16.0;
	ChanceOfRolling[3] = 4.0/16.0;
	ChanceOfRolling[4] = 1.0/16.0;
	
	StandingRisk: []f32 = make([]f32, len(Options));
	defer delete(StandingRisk);
	MovingRisk: []f32 = make([]f32, len(Options));
	defer delete(MovingRisk);
	
	StayingIsSafe: []bool = make([]bool, len(Options));
	defer delete(StayingIsSafe);
	MovingIsSafe: []bool = make([]bool, len(Options));
	defer delete(MovingIsSafe);
	
	for TokenIndex, Index in Options
	{
		Position := PotentialMoves[TokenIndex];
		Token: token = Player.Tokens[TokenIndex]; // Note:

		if(Position.X == 2 && Position.Y == 3)
		{
			MovingIsSafe[Index] = true;
		}
		else
		{
			MovingIsSafe[Index] = false;
		}

		if(Token.Position.X == 2 && Token.Position.Y == 3)
		{
			StayingIsSafe[Index] = true;
		}
		else
		{
			StayingIsSafe[Index] = false;
		}
		
		// println("Token", TokenIndex + 1, "contemplates...");
		for EnemyPosition in EnemyTokens
		{
			// printf("Enemy at %c%d\n", EnemyPosition.Y + 'a', EnemyPosition.X);
			for Chance, Roll in ChanceOfRolling
			{
				if(Roll == 0)
				{
					continue;
				}
				
				WalkPosition: board_position = WalkFrom(EnemyPosition, auto_cast Roll, Player);
				if(Token.Position.X == 2 &&
				   WalkPosition.X == Token.Position.X &&
				   WalkPosition.Y == Token.Position.Y)
				{
					if(StayingIsSafe[Index])
					{
						// printf(" Can not take me if I don't move as I am safe\n");
					}
					else
					{
						// printf(" Can take me at %c%d if I stay here with a roll of %d\n", Token.Position.Y + 'a', Token.Position.X, Roll);
						StandingRisk[Index] += Chance;
					}
				}
				else if(WalkPosition.X == Position.X &&
						WalkPosition.Y == Position.Y)
				{
					if(MovingIsSafe[Index])
					{
						// printf(" Can not take me if I go into armistice at d2\n");
					}
					else
					{
						// printf(" Can take me at %c%d if I move with a roll of %d\n", Position.Y + 'a', Position.X, Roll);
						MovingRisk[Index] += Chance;
					}
				}
			}
		}
	}
	
	GoodOptions: [dynamic]byte;
	defer delete(GoodOptions);
	OkayOptions: [dynamic]byte;
	defer delete(OkayOptions);
	BestOption: int;
	MaxRiskReduction: f32 = 0.0;
	FirstOkayOption: int = -1;
	LesserOfEvils: int;
	MinRiskAddition: f32 = 1.0;
	for Chance, Index in StandingRisk
	{
		Difference: f32 = MovingRisk[Index] - StandingRisk[Index];
		
		if(Difference < 0.0)
		{
			append(&GoodOptions, auto_cast Index);
			if(Difference < MaxRiskReduction)
			{
				BestOption = Index;
			}
		}
		else if(Difference == 0.0 && FirstOkayOption == -1)
		{
			append(&OkayOptions, auto_cast Index);
		}
		else if(Difference > 0.0 && Difference < MinRiskAddition)
		{
			LesserOfEvils = Index;
		}
	}
	
	if(len(GoodOptions) > 0)
	{
		// println("The best choice as I see it is", BestOption + 1);
		Result = BestOption;
		HappyWithMove = true;
	}
	else if(len(OkayOptions) > 0)
	{
		// println("Whatever's good");
		
		Result = auto_cast OkayOptions[int(rand.int31())%len(OkayOptions)];
		//Result = FirstOkayOption; // Note: I think this would be a racer? Correct?
	}
	else
	{
		// println("Unfortunate I must make this move...");
		Result = LesserOfEvils;
	}
	
	// println();
	
	return Result, HappyWithMove;
}

AIDetermineRacerChoice :: proc(PotentialMoves: []board_position, Options: []byte) -> int
{
	Result: int = -1;
	
	// Note: I think this is all we have to do, right?
	Result = 0;
	
	return Result;
}

AIDetermineAggressiveEconomicChoice :: proc(PotentialMoves: []board_position, Options: []byte) -> int
{
	Result: int = -1;
	
	SecondChoice: int = -1;
	
	for TokenIndex, Index in Options
	{
		Position := PotentialMoves[TokenIndex];
		TileType: byte = GetTileTypeFromBoard(Position);
		TileToken: ^token = GetTokenFromBoard(Position);
		
		// Note: This Tile's Token we know to be an enemies, and we _can_ take it
		if(TileToken != nil)
		{
			Result = Index;
			break;
		}
		else if((TileType == 1 || TileType == 2) && SecondChoice == -1)
		{
			SecondChoice = Index;
		}
	}
	
	if(Result == -1)
	{
		if(SecondChoice >= 0)
		{
			Result = SecondChoice;
		}
		else
		{	
			Result = int(rand.int31())%len(Options);
		}
	}
	
	return Result;
}

AIDetermineAggressiveRacerChoice :: proc(PotentialMoves: []board_position, Options: []byte) -> int
{
	Result: int = -1;
	
	SecondChoice: int = -1;
	
	for TokenIndex, Index in Options
	{
		Position := PotentialMoves[TokenIndex];
		TileType: byte = GetTileTypeFromBoard(Position);
		TileToken: ^token = GetTokenFromBoard(Position);
		
		// Note: This Tile's Token we know to be an enemies, and we _can_ take it
		if(TileToken != nil)
		{
			Result = Index;
			break;
		}
		else if((TileType == 1 || TileType == 2) && SecondChoice == -1)
		{
			SecondChoice = Index;
		}
	}
	
	if(Result == -1)
	{
		Result = 0;
	}
	
	return Result;
}

AIDetermineEconomicRacerChoice :: proc(PotentialMoves: []board_position, Options: []byte) -> int
{
	Result: int = -1;
	
	for TokenIndex, Index in Options
	{
		Position := PotentialMoves[TokenIndex];
		TileType: byte = GetTileTypeFromBoard(Position);
		
		if(TileType == 1 || TileType == 2)
		{
			Result = Index;
			break;
		}
	}
	
	if(Result == -1)
	{
		Result = 0;
	}
	
	return Result;
}

AIMakeMove :: proc(State: ^game_state, MoveCount: byte, Config: config) -> board_position
{
	Result: board_position;
	
	Player: player = State.Players[State.Turn];
	
	PotentialMoves: []board_position = GetPotentialMoves(Player, MoveCount);
	defer delete(PotentialMoves);
	
	ValidOptions: [dynamic]byte;
	defer delete(ValidOptions);

	for Position, Index in PotentialMoves
	{
		Token: token = Player.Tokens[Index];
		
		if(Position.X > 0)
		{
			append(&ValidOptions, byte(Index));
			/*
			LetterPosition: rune = 'a' + (rune)(Position.Y);
			if(Token.Position.X == 0)
			{
				if(!Config.DisablePrint)
				{
					printf("Token %d can move onto the board at %c%d\n", Index + 1, LetterPosition, Position.X);
				}
			}
			else if((Position.X == 1 || Position.Y == 3) &&
					Position.Y == 5)
			{
				if(!Config.DisablePrint)
				{
					printf("Token %d can retire\n", Index + 1);
				}
			}
			else
			{
				if(!Config.DisablePrint)
				{
					printf("Token %d can move to %c%d\n", Index + 1, LetterPosition, Position.X);
				}
			}
			*/
		}
	}
	
	if(len(ValidOptions) > 0)
	{
		Choice: int;
		#partial switch Config.AI[State.Turn].Behavior
		{
			case AIBehavior_Borg:
				panic("At The Disco!");
			case AIBehavior_Random:
				Choice = int(rand.int31())%len(ValidOptions);
			case AIBehavior_Aggresive:
				HappyWithMove: bool;
				Choice, HappyWithMove = AIDetermineAggressiveChoice(PotentialMoves, ValidOptions[:]);
			case AIBehavior_Defensive:
				HappyWithMove: bool;
				Choice, HappyWithMove = AIDetermineDefensiveChoice(PotentialMoves, ValidOptions[:], Player, MoveCount);
			case AIBehavior_Economic:
				HappyWithMove: bool;
				Choice, HappyWithMove = AIDetermineEconomicChoice(PotentialMoves, ValidOptions[:]);
			case AIBehavior_Racer:
				Choice = AIDetermineRacerChoice(PotentialMoves, ValidOptions[:]);
			case AIBehavior_AggressiveDefensive:
				HappyWithMove: bool;
				Choice, HappyWithMove = AIDetermineAggressiveChoice(PotentialMoves, ValidOptions[:]);
				if(HappyWithMove == false)
				{
					Choice, HappyWithMove = AIDetermineDefensiveChoice(PotentialMoves, ValidOptions[:], Player, MoveCount);
				}
			case AIBehavior_AggressiveEconomic:
				Choice = AIDetermineAggressiveEconomicChoice(PotentialMoves, ValidOptions[:]);
			case AIBehavior_AggressiveRacer:
				Choice = AIDetermineAggressiveRacerChoice(PotentialMoves, ValidOptions[:]);
			case AIBehavior_DefensiveAggressive:
				HappyWithMove: bool;
				Choice, HappyWithMove = AIDetermineDefensiveChoice(PotentialMoves, ValidOptions[:], Player, MoveCount);
				if(HappyWithMove == false)
				{
					Choice, HappyWithMove = AIDetermineAggressiveChoice(PotentialMoves, ValidOptions[:]);
				}
			case AIBehavior_DefensiveEconomic:
				HappyWithMove: bool;
				Choice, HappyWithMove = AIDetermineDefensiveChoice(PotentialMoves, ValidOptions[:], Player, MoveCount);
				if(HappyWithMove == false)
				{
					Choice, HappyWithMove = AIDetermineEconomicChoice(PotentialMoves, ValidOptions[:]);
				}
			case AIBehavior_DefensiveRacer:
				HappyWithMove: bool;
				Choice, HappyWithMove = AIDetermineDefensiveChoice(PotentialMoves, ValidOptions[:], Player, MoveCount);
				if(HappyWithMove == false)
				{
					Choice = AIDetermineRacerChoice(PotentialMoves, ValidOptions[:]);
				}
			case AIBehavior_EconomicAggressive:
				Choice = AIDetermineEconomicAggressiveChoice(PotentialMoves, ValidOptions[:]);
			case AIBehavior_EconomicDefensive:
				HappyWithMove: bool;
				Choice, HappyWithMove = AIDetermineEconomicChoice(PotentialMoves, ValidOptions[:]);
				if(HappyWithMove == false)
				{
					Choice, HappyWithMove = AIDetermineDefensiveChoice(PotentialMoves, ValidOptions[:], Player, MoveCount);
				}
			case AIBehavior_EconomicRacer:
				Choice = AIDetermineEconomicRacerChoice(PotentialMoves, ValidOptions[:]);
		}
		MakeMove(State, MoveCount, ValidOptions[Choice]);
		Result = PotentialMoves[ValidOptions[Choice]];
	}
	else
	{
		Result = {0, 0};
	}
	
	return Result;
}
