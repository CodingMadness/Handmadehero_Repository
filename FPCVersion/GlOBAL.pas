unit GLOBAL;

{$mode objfpc}

interface

uses Windows;

const
  MIN_WIDTH = 800;

const
  MIN_HEIGHT = 600;

var
  GAMEHWND: HWND;

type
  PRect = ^Rect;
  Win32Message = MSG;
  Rectangle = RECT;
  TMaxBitSize = 1..64;


  THelper = class
    //function bitsOf<T>(const a: T): TMaxBitSize;
  end;


implementation

(* function THelper.bitsOf<T>: TMaxBitSize;
begin
  Result := TMaxBitSize(8 * sizeOf(T));
end;
  *)
end.
