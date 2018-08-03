Unit GameSound;

  {$modeswitch advancedrecords}

  INTERFACE
      USES
        Windows, mmsystem, sysutils, LazLogger, DirectSound;

      const
        SENSEFUL_ERROR_LENGTH = 38;
        DEFAULT_CURSOR_POS = -1;

      TYPE
        TWaveCycle = record
          const PI = 3.14159265358979323846;
          const WAVEFREQUENCY = 256; //1-HZ=256
          const HALFWAVEFREQUENCY = WAVEFREQUENCY div 2; //0.5 HZ = 128
          const DURATION = 2.0 * PI;
        end;

        TSampleInfo = record
          const SAMPLEBITS = 16;
          const SIZE = 4;
          const CHANNELCOUNT = 2;
          const CHANNELVOLUME = 10000;
          const SAMPLESPERSECOND = 48000;
          const LATENCYSAMPLECOUNT = SAMPLESPERSECOND div 16;
          const LATENCYSAMPLEBYTECOUNT = LATENCYSAMPLECOUNT * SIZE;
          const SAMPLESPERWAVECYCLE = SAMPLESPERSECOND div TWaveCycle.WAVEFREQUENCY;
        end;

        TSoundVolume = -(TSampleInfo.CHANNELVOLUME)..(TSampleInfo.CHANNELVOLUME);

        TSampleChannels = record
          Left, Right: TSoundVolume;
        end;

        PSampleChannels = ^TSampleChannels;

        TSampleIndex =  0..(TSampleInfo.SAMPLESPERSECOND-1);

        TBufferSize  =  0..(TSampleInfo.SAMPLESPERSECOND * TSampleInfo.SIZE);

        TCursorPosition = DEFAULT_CURSOR_POS..high(DWORD);

        ErrorTextMessage = String[SENSEFUL_ERROR_LENGTH];

        TRegion = record
         Start: DWORD;
         Size: TBufferSize;
       end;

        TRegionState = record
          Locked: BOOL;
          ErrorMsg: ErrorTextMessage;
          HowOftenCalled: integer;
        end;

        TSystemsCursor = record
          PlayCursor, WriteCursor, TargetCursor: TCursorPosition;
        end;

        PRegion = ^TRegion;

        TLockableRegion = record
         ToLock: TRegion;
         LockedRegions: array[0..1] of TRegion;
         State: TRegionState;
         BuffersCursor: TSystemsCursor;
        end;

        WIN32SOUNDBUFFER = IDirectSoundBuffer;

        TSoundBuffer = record
         Playing: BOOL;
         RunningSampleIndex: TSampleIndex;
         Content: WIN32SOUNDBUFFER;
         LockableRegion: TLockableRegion;
        end;

        PSoundBuffer = ^TSoundBuffer;

      function EnableSoundProcessing(const hwnd: HWND): BOOL;
      procedure CreateSoundBuffer(var soundBuffer: TSoundBuffer);
      procedure WriteSamplesToSoundBuffer(const soundBuffer: PSoundBuffer);
      procedure PlayTheSoundBuffer(const soundBuffer: PSoundBuffer);

  IMPLEMENTATION
      var
        DS8: IDirectSound8;
        logGroup: PLazLoggerLogGroup;
      {PRIVATE}
      function ErrCodeToErrMsg(const errorCode: HRESULT): ErrorTextMessage;
      var
        bufferFlags: DWORD;
        currLang: DWORD;
        msgBuf: LPSTR;
      begin
        msgBuf := nil;
        bufferFlags := FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS;
        currLang := MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT);
        FormatMessageA(bufferFlags, nil, errorCode, currLang, LPSTR(@msgBuf), 0, nil);
        result := ErrorTextMessage(msgBuf^);
        LocalFree(PQWord(@msgBuf)^);
      end;

      procedure UnlockRegionsWithin(const soundBuffer: PSoundBuffer);
      var
        result: HRESULT;
      begin
        with soundBuffer^.LockableRegion do
        begin
          result := soundBuffer^.Content.Unlock
          (
            Pointer(@LockedRegions[0].Start), LockedRegions[0].Size,
            Pointer(@LockedRegions[1].Start), LockedRegions[1].Size
          );

          State.Locked := (result < 0);
          State.ErrorMsg := ErrCodeToErrMsg(result);
          State.HowOftenCalled += 1;
        end;
      end;

      procedure LockRegionsWithin(const soundBuffer: PSoundBuffer);
        function compute_region_toLock: TRegion;
          var
            positionValid: boolean;
            StartByteToLockFrom: TBufferSize;
            nrOfBytesToLock: TBufferSize = 0;
        begin
          with soundBuffer^.LockableRegion.BuffersCursor do
          begin
            positionValid := soundBuffer^.Content.
                                          GetCurrentPosition(@PlayCursor, @WriteCursor) >= 0;
            if positionValid then
            begin
              TargetCursor := (TSampleInfo.LATENCYSAMPLEBYTECOUNT + PlayCursor) mod high(TBufferSize);
              StartByteToLockFrom := (soundBuffer^.RunningSampleIndex * TSampleInfo.SIZE) mod high(TBufferSize);

              if StartByteToLockFrom < TargetCursor then
                nrOfBytesToLock := TBufferSize(TargetCursor - StartByteToLockFrom)

              else if StartByteToLockFrom >= TargetCursor then
                nrOfBytesToLock := TBufferSize((high(TBufferSIZE) - StartByteToLockFrom) + TargetCursor);

              result.Size := nrOfBytesToLock;
              result.Start := StartByteToLockFrom;
            end;
          end;
        end;

        function get_fix_region: TRegion; inline;
        var
          first: Byte = 0;
        begin
          result.Start := first;
          result.Size := TSampleInfo.LATENCYSAMPLEBYTECOUNT;
        end;

        procedure internal_lock; inline;
        var
          res: HRESULT;
          from, cntToWrite: DWORD;
          ptr0, ptr1: Pointer;
          ppStart0, ppStart1: PPointer;
          pSize0, pSize1: PDWORD;
        begin
          with soundBuffer^.LockableRegion do
          begin
            from := ToLock.Start;
            cntToWrite := ToLock.Size;

            ptr0 := Pointer(@LockedRegions[0].Start);
            ptr1 := Pointer(@LockedRegions[1].Start);

            ppStart0 := @ptr0;
            pSize0 := PDWORD(@LockedRegions[0].Size);

            ppStart1 := @ptr1;
            pSize1 := PDWORD(@LockedRegions[1].Size);

            res := soundBuffer^.Content.Lock(from, cntToWrite, ppStart0, pSize0, ppStart1, pSize1, 0);

            State.Locked := (res >= 0);
            //State.ErrorMsg := ErrCodeToErrMsg(result);
            State.HowOftenCalled += 1;
          end;
        end;
      begin
        if not soundBuffer^.Playing then
          soundBuffer^.LockableRegion.ToLock := get_fix_region()

        else
          soundBuffer^.LockableRegion.ToLock := compute_region_toLock();

        internal_lock();
      end;

      procedure WriteSamplesTolockedRegion(lockedRegion: PRegion; var runningSampleIndex: TSampleIndex);
      var
       totalSampleCount: TSampleIndex = 0;
       firstSample: PSampleChannels;
       volume: TSoundVolume;
       SampleIndex: TSampleIndex;

      function get_square_volume: TSoundVolume; inline;
      var relativeSampleIndex: TSampleIndex;
      begin
        relativeSampleIndex := (runningSampleIndex div TWaveCycle.HALFWAVEFREQUENCY);
        if (relativeSampleIndex mod 2) = 0 then
          result := TSampleInfo.CHANNELVOLUME
        else
          result := -TSampleInfo.CHANNELVOLUME;
      end;

      function get_sine_volume: TSoundVolume; inline;
      var time, sinus: ValReal;
      begin
        time := ValReal(TWaveCycle.DURATION * Real(runningSampleIndex) / Real(TSampleInfo.SAMPLESPERWAVECYCLE));
        sinus := ValReal(sin(time));
        result := TSoundVolume(Round(sinus * TSampleInfo.CHANNELVOLUME));
      end;

      begin
        if lockedRegion^.Size = 0 then exit;

        totalSampleCount := TSampleIndex(lockedRegion^.Size div TSampleInfo.SIZE) - 1;

        firstSample := PSampleChannels(@lockedRegion^.Start);

        for SampleIndex := 0 to (totalSampleCount) do
        begin
          DebugLn(logGroup, 'SampleIndex = ' + IntToStr(SampleIndex), ', totalSampleCount = ' + IntToStr(totalSampleCount));
          volume := get_sine_volume;
          firstSample^.Left := volume;
          firstSample^.Right := volume;
          inc(firstSample);
          inc(runningSampleIndex);
        end;
      end;
      {PRIVATE}


      {PUBLIC}
      function EnableSoundProcessing(const hwnd: HWND): BOOL; inline;
      begin
        if hwnd = 0 then exit;
        result := (DirectSoundCreate8(nil, DS8, nil) >= 0);
        result := result and (Ds8.SetCooperativeLevel(hwnd, DSSCL_PRIORITY) >= 0);
      end;

      procedure CreateSoundBuffer(var soundBuffer: TSoundBuffer);
        var bufferCreated: boolean;
        var bfdesc : DSBUFFERDESC;
        var wFormat: WAVEFORMATEX;
      begin
        wFormat := default(WAVEFORMATEX);
        wFormat.cbSize := 0;
        wFormat.wFormatTag := WAVE_FORMAT_PCM;
        wFormat.nChannels := TSampleInfo.CHANNELCOUNT;
        wFormat.nSamplesPerSec := TSampleInfo.SAMPLESPERSECOND;
        wFormat.wBitsPerSample := 16;
        wFormat.nBlockAlign := Word((WFORMAT.nChannels * WFORMAT.wBitsPerSample) div 8);
        wFormat.nAvgBytesPerSec := WFORMAT.nBlockAlign * WFORMAT.nSamplesPerSec;

        bfdesc := default(DSBUFFERDESC);
        bfdesc.dwSize := sizeOf(DSBUFFERDESC);
        bfdesc.dwBufferBytes := high(TBufferSize);
        bfdesc.dwFlags := 0;
        bfdesc.lpwfxFormat:= @wFormat;

        soundBuffer := default(TSoundBuffer);
        soundBuffer.Playing := false;
        soundBuffer.RunningSampleIndex := 0;
        soundBuffer.LockableRegion.ToLock := default(TRegion);
        soundBuffer.LockableRegion.LockedRegions[0] := default(TRegion);
        soundBuffer.LockableRegion.LockedRegions[1] := default(TRegion);
        soundBuffer.LockableRegion.BuffersCursor.PlayCursor :=  DEFAULT_CURSOR_POS;
        soundBuffer.LockableRegion.BuffersCursor.WriteCursor := DEFAULT_CURSOR_POS;
        soundBuffer.LockableRegion.BuffersCursor.TargetCursor := DEFAULT_CURSOR_POS;
        soundBuffer.LockableRegion.State.Locked   :=    false;
        soundBuffer.LockableRegion.State.ErrorMsg :=    '';

        logGroup := DebugLogger.FindOrRegisterLogGroup('GameSoundLogger', true);

        bufferCreated := DS8.CreateSoundBuffer(bfdesc, soundBuffer.Content, nil) >= 0;

        if not bufferCreated then raise Exception.Create('Somehow the Creation of soundBuffer didnt work properly');
      end;

      procedure WriteSamplesToSoundBuffer(const soundBuffer: PSoundBuffer);
      begin
        LockRegionsWithin(soundBuffer);

        if not soundBuffer^.LockableRegion.State.Locked then
          raise Exception.Create(
                                 'The specified region could not be locked because of: ' + soundBuffer^.LockableRegion.State.ErrorMsg +
                                 IntToStr(soundBuffer^.LockableRegion.State.HowOftenCalled));

        (*LockedRegion1*)
        WriteSamplesTolockedRegion(@(soundBuffer^.LockableRegion.LockedRegions[0]), soundBuffer^.RunningSampleIndex);

        (*LockedRegion2*)
        WriteSamplesTolockedRegion(@(soundBuffer^.LockableRegion.LockedRegions[1]), soundBuffer^.RunningSampleIndex);

        UnlockRegionsWithin(soundBuffer);

        if soundBuffer^.LockableRegion.State.Locked then
          raise Exception.Create('The specified region could not be unlocked because of: ' + soundBuffer^.LockableRegion.State.ErrorMsg);
      end;

      procedure PlayTheSoundBuffer(const soundBuffer: PSoundBuffer); inline;
      begin
        if not soundBuffer^.Playing then
          soundBuffer^.Playing := soundBuffer^.Content.Play(0, 0, DSBPLAY_LOOPING) >= 0;
      end;
      {PUBLIC}
  end.
