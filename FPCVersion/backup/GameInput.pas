unit GameInput;

  interface
    uses windows, sysutils;

    function IsKeyPressedOnce(const keyCode, lParam: UInt32; keyChar: Char): BOOL;

  implementation
    const PREV_KEY_STATE = (1 shl 30);
    const TRANSITION_STATE = (1 shl 31);

    function IsKeyPressedOnce(const keyCode, lParam: UInt32; keyChar: Char): BOOL;
    var displaybleChar : Char;
    var wasDown, isDown: longword;
    begin
      displaybleChar := UpCase(Char(keyCode));
      keyChar := UpCase(Char(keyChar));

      wasDown := (lParam and PREV_KEY_STATE) ;
      isDown  := (lParam and TRANSITION_STATE);

      result := (wasDown <> isDown) and (displaybleChar = keyChar);
    end;
end.
