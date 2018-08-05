unit Helper;
{$mode objfpc}{$H+}

interface
    uses
      Classes, windows, SysUtils;

    const
      SENSEFUL_ERROR_LENGTH = 38;

    type
      TCallReturnMessage = String[SENSEFUL_ERROR_LENGTH];

      TLockState = record
        ID: Extended;
        Locked: BOOL;
        Message: TCallReturnMessage;
      end;

      PLockState = ^TLockState;

      ELock = class(Exception)
      private
        fLockState: TLockState;

        function GetLocked: bool;
        function GetReturnMessage: TCallReturnMessage;
        function GetID: Extended;

      public
        property Locked:        BOOL                   read GetLocked;
        property ReturnMessage: TCallReturnMessage     read GetReturnMessage;
        property CurrentID:     Extended               read GetID;
        constructor Init(const currState: PLockState);
      end;

      EUnlock = class(ELock);

     function GetFunctionReturnMessage(const returnCode: HRESULT): TCallReturnMessage;

implementation
    constructor ELock.Init(const currState: PLockState);
    begin
      fLockState := currState;
    end;

    function ELock.GetLocked: BOOL;
    begin
      result := fLockState^.Locked;
    end;

    function ELock.GetReturnMessage: TCallReturnMessage;
    begin
      result := fLockState^.Message;
    end;

    function ELock.GetID: Extended;
    begin
      result := fLockState^.ID;
    end;

    function GetFunctionReturnMessage(const returnCode: HRESULT): TCallReturnMessage;
    var
      bufferFlags: DWORD;
      currLang: DWORD;
      msgBuf: LPSTR;
      hMem: HLOCAL;
    begin
      msgBuf := nil;
      bufferFlags := DWORD(FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS);
      currLang := DWORD(MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT));
      FormatMessageA(bufferFlags, nil, DWORD(returnCode), currLang, LPSTR(@msgBuf), 0, nil);  //range check error
      result := TCallReturnMessage(msgBuf);
      hMem := PQWord(@msgBuf)^;
      LocalFree(hMem);
      msgBuf := nil;
    end;
end.

