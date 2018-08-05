unit Helper;
{$mode objfpc}{$H+}

interface
    uses
      Classes, windows, SysUtils;

    const
      SENSEFUL_ERROR_LENGTH = 38;

    type
      TCallReturnMessage = String[SENSEFUL_ERROR_LENGTH];

      ELocking = class(Exception)
      private
        fLocked: BOOL;
        fReturnMsg: TCallReturnMessage;
      public
        property Locked: BOOL read fLocked;
        property ReturnMessage: TCallReturnMessage read fReturnMsg;
        constructor Create(const msg: TCallReturnMessage; isLocked: BOOL);
      end;

      //EUnlocking = class(Elocking);

     function GetFunctionReturnMessage(const returnCode: HRESULT): TCallReturnMessage;

implementation
    constructor Elocking.Create(const msg: TCallReturnMessage; isLocked: BOOL);
    begin
      fLocked := isLocked;
      fReturnMsg := msg;
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
      currLang := MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT);
      FormatMessageA(bufferFlags, nil, returnCode, currLang, LPSTR(@msgBuf), 0, nil);
      result := TCallReturnMessage(msgBuf);
      hMem := PQWord(@msgBuf)^;
      LocalFree(hMem);
      msgBuf := nil;
    end;
end.

