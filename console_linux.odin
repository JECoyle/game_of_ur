package main

foreign import "system:c"

using import "core:fmt"
using import "core:strings"
import "core:os"
// import "core:sys/linux"

coord :: struct
{
	X: i16,
	Y: i16,
}

rect :: struct
{
	Left: i16,
	Top: i16,
	Right: i16,
	Bottom: i16
}

console_info :: struct
{
	Size: coord,
	CursorPosition: coord,
	Attributes: u16,
	Window: rect,
	MaximumWindowSize: coord
}

SetCursorPosition :: proc(X, Y: i16)
{
	printf("\x1b[%d;%dH", Y + 1, X + 1);
}

ClearConsole :: proc()
{
	os.write(1, ([]u8)("\x1b[2J"));
	os.write(1, ([]u8)("\x1b[0;0H"));
}

WriteToConsoleHere :: proc(String: string)
{
	printf("%s", String);
}
WriteToConsoleAt :: proc(String: string, X,Y: i16)
{
	os.write(1, ([]u8)("\x1b7"));
	printf("\x1b[%d;%dH", Y + 1, X);
	printf("%s", String);
	os.write(1, ([]u8)("\x1b8"));
}
WriteToConsole :: proc{WriteToConsoleHere, WriteToConsoleAt};

PrintFormatAt :: proc(X,Y: i16, Format: string, Arguments: ..any) -> int
{
	Result: int = ---;
	
	os.write(1, ([]u8)("\x1b7"));
	SetCursorPosition(X, Y);
	Result = printf(Format, ..Arguments);
	os.write(1, ([]u8)("\x1b8"));

	return Result;
}

SetConsoleCodePage :: proc(CodePageID: u32)
{
	// Note: I think all Linux stuff is like this?
}

GetConsoleCodePage :: proc() -> u32
{
	// Note: I think all Linux stuff is like this?
	return 65001;
}

/*
SetConsoleSize :: proc(X, Y: u32)
{
	Coordinates: coord = {auto_cast X, auto_cast Y};
	SetConsoleScreenBufferSize(os.stdout, Coordinates);
}
*/
