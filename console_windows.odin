package main

foreign import "system:kernel32.lib"

import "core:fmt"
import "core:strings"
import "core:os"
import "core:sys/win32"

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

@(default_calling_convention="std")
foreign kernel32
{
	@(link_name="SetConsoleCursorPosition") SetConsoleCursorPosition :: proc(Handle: os.Handle, Coordinates: coord) -> win32.Bool ---;
	@(link_name="GetConsoleScreenBufferInfo") GetConsoleInfo :: proc(Handle: os.Handle, ConsoleInfo: ^console_info) -> win32.Bool ---;
	@(link_name="FillConsoleOutputCharacterW") FillConsoleWithCharacter :: proc(Handle: os.Handle, Character: i32, Count: u32, WriteCoord: coord, CharactersWritten: ^u32) -> win32.Bool ---;
	@(link_name="WriteConsoleW")  WriteConsole :: proc(Handle: os.Handle, Buffer: rawptr, CharactersToWrite: u32, CharactersWritten: ^u32, _Reserved: rawptr) -> win32.Bool ---;
	@(link_name="SetConsoleCP") SetConsoleCP :: proc(CodePageID: u32) -> win32.Bool ---;
	@(link_name="GetConsoleCP") GetConsoleCP :: proc() -> u32 ---;
	@(link_name="SetConsoleOutputCP") SetConsoleOutputCP :: proc(CodePageID: u32) -> win32.Bool ---;
	@(link_name="SetConsoleScreenBufferSize") SetConsoleScreenBufferSize :: proc(Handle: os.Handle, Size: coord) -> win32.Bool ---;
}

SetCursorPosition :: proc(X, Y: i16)
{
	Coordinates: coord = {X, Y};
	SetConsoleCursorPosition(os.stdout, Coordinates);
}

ClearConsole :: proc()
{
	ConsoleInfo: console_info;
	GetConsoleInfo(os.stdout, &ConsoleInfo);
	
	// Note: in one dimension
	ConsoleSize: u32 = auto_cast(ConsoleInfo.Size.X*ConsoleInfo.Size.Y);
	ZeroPosition: coord = {0, 0};	
	CharactersWritten: u32;
	FillConsoleWithCharacter(os.stdout, ' ', ConsoleSize, ZeroPosition, &CharactersWritten);
	
	SetCursorPosition(0, 0);
	// os.write(1, {0x1b, '[', '2', 'J'}); // Note: only for linux :(
}

WriteToConsoleHere :: proc(String: string)
{
	Buffer: []u16 = win32.utf8_to_utf16(String);
	defer delete(Buffer);
	CharactersWritten: u32;
	WriteConsole(os.stdout, rawptr(&Buffer[0]), u32(len(Buffer)), &CharactersWritten, nil);
}
WriteToConsoleAt :: proc(String: string, X,Y: i16)
{
	ConsoleInfo: console_info;
	GetConsoleInfo(os.stdout, &ConsoleInfo);
	CursorPosition: coord = ConsoleInfo.CursorPosition;
	SetCursorPosition(X, Y);
	
	Buffer: []u16 = win32.utf8_to_utf16(String);
	CharactersWritten: u32;
	WriteConsole(os.stdout, rawptr(&Buffer[0]), u32(len(Buffer)), &CharactersWritten, nil);

	SetCursorPosition(CursorPosition.X, CursorPosition.Y);
}
WriteToConsole :: proc{WriteToConsoleHere, WriteToConsoleAt};

PrintFormatAt :: proc(X,Y: i16, Format: string, Arguments: ..any) -> int
{
	Result: int = ---;
	
	ConsoleInfo: console_info;
	GetConsoleInfo(os.stdout, &ConsoleInfo);
	CursorPosition: coord = ConsoleInfo.CursorPosition;
	SetCursorPosition(X, Y);
	
	Result = fmt.printf(Format, ..Arguments);

	SetCursorPosition(CursorPosition.X, CursorPosition.Y);
	
	return Result;
}

SetConsoleCodePage :: proc(CodePageID: u32)
{
	SetConsoleCP(CodePageID);
	SetConsoleOutputCP(CodePageID);
}

GetConsoleCodePage :: proc() -> u32
{
	Result: u32 = 0;
	
	Result = GetConsoleCP();
	
	return Result;
}

/*
SetConsoleSize :: proc(X, Y: u32)
{
	Coordinates: coord = {auto_cast X, auto_cast Y};
	SetConsoleScreenBufferSize(os.stdout, Coordinates);
}
*/