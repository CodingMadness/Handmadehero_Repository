Unit GameSound;

  {$modeswitch advancedrecords}

  INTERFACE
      USES
        Windows, Helper, mmsystem, sysutils, DirectSound;

      const
        DEFAULT_CURSOR_POS = -1;

      TYPE
        TWaveCycle = record
          const PI = 3.14159265358979323846;
          const WAVEFREQUENCY = 256;//1HZ=256
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

        TSoundVolume = -TSampleInfo.CHANNELVOLUME..TSampleInfo.CHANNELVOLUME;

        TSine = Single;

        TSampleChannels = record
          Left, Right: TSoundVolume;
        end;

        PSampleChannels = ^TSampleChannels;

        TSampleIndex =  0..(TSampleInfo.SAMPLESPERSECOND-1);

        TInfiniteSampleIndex = QWORD;

        TBufferSize  =  0..(TSampleInfo.SAMPLESPERSECOND * TSampleInfo.SIZE);

        TCursorPosition = DEFAULT_CURSOR_POS..high(DWORD);

        TRegion = record
         Start: LPVOID;
         Size: TBufferSize;
       end;

        TSystemCursor = record
          PlayCursor,
          WriteCursor,
          TargetCursor: TCursorPosition;
        end;

        TManipulatableRegion = record
         ToLock: TRegion;
         ManipulatedRegions: array[0..1] of TRegion;
         Cursor: TSystemCursor;
         ManipulatedRegionState: TManipulatedRegionState;
        end;

        TSoundBuffer = record
          Playing: BOOL;
          WavePosition: TSine;
          Content: IDirectSoundBuffer;
          GlobalSampleIndex: TInfiniteSampleIndex;
          ManipulatableRegion: TManipulatableRegion;
        end;

        PSoundBuffer = ^TSoundBuffer;

      function EnableSoundProcessing(const hwnd: HWND): boolean;
      procedure CreateSoundBuffer(var soundBuffer: TSoundBuffer);
      procedure WriteSamplesToSoundBuffer(const soundBuffer: PSoundBuffer);
      procedure PlayTheSoundBuffer(const soundBuffer: PSoundBuffer);

  IMPLEMENTATION
      var
        DS8: IDIRECTSOUND8;

      {PRIVATE}
      procedure UnlockRegionsWithin(const soundBuffer: PSoundBuffer);
        procedure IndentifyUnlockInfo(const code: HRESULT);
        begin
          with soundBuffer^.ManipulatableRegion.ManipulatedRegionState.UnlockState do
          begin
            infoAfterUnlock.Number += 1;
            infoAfterUnlock.CallSuceeded := (code >= 0);

            if infoAfterUnlock.CallSuceeded then
              SuceededUntilNow += 1
            else
              FailedUntilNow += 1;

            infoAfterUnlock.ReturnMessage := GetFunctionReturnMessage(code);
          end;
        end;
      var
        code: HRESULT;
      begin
        with soundBuffer^.ManipulatableRegion do
        begin
          code := soundBuffer^.Content.Unlock(ManipulatedRegions[0].Start, ManipulatedRegions[0].Size,
                                              ManipulatedRegions[1].Start, ManipulatedRegions[1].Size);
          IndentifyUnlockInfo(code);
        end;
      end;

      procedure LockRegionsWithin(const soundBuffer: PSoundBuffer);
      {$Region NESTED ROUTINES}
        function fixRegion: TRegion; inline;
        var first: DWORD = 0;
        begin
          result.Start := LPVOID(@first);
          result.Size := TSampleInfo.LATENCYSAMPLECOUNT;
        end;

        function computedRegion: TRegion; inline;
        var
          positionValid: boolean;
          StartByteToLockFrom: TBufferSize;
          nrOfBytesToLock: TBufferSize = 0;
        begin
          with soundBuffer^.ManipulatableRegion.Cursor do
          begin
            positionValid := soundBuffer^.Content.
                                          GetCurrentPosition(@PlayCursor, @WriteCursor) >= 0;
            if positionValid then
            begin
              TargetCursor := TCursorPosition((TSampleInfo.LATENCYSAMPLEBYTECOUNT + PlayCursor) mod high(TBufferSize));
              StartByteToLockFrom := (soundBuffer^.GlobalSampleIndex * TSampleInfo.SIZE) mod high(TBufferSize);

              if StartByteToLockFrom < TargetCursor then
                nrOfBytesToLock := TBufferSize(TargetCursor - StartByteToLockFrom)

              else if StartByteToLockFrom >= TargetCursor then
                nrOfBytesToLock := TBufferSize((high(TBufferSIZE) - StartByteToLockFrom) + TargetCursor);

              result.Size := nrOfBytesToLock;
              result.Start := LPVOID(@StartByteToLockFrom);
            end;
          end;
        end;

        procedure IndentifyLockInfo(const code: HRESULT); inline;
        begin
         with soundBuffer^.ManipulatableRegion.ManipulatedRegionState.LockState do
          begin
            infoAfterLock.Number += 1;
            infoAfterLock.CallSuceeded := (code >= 0);

            if infoAfterLock.CallSuceeded then
              SuceededUntilNow += 1
            else
              FailedUntilNow += 1;

            infoAfterLock.ReturnMessage := GetFunctionReturnMessage(code);
          end;
        end;

        function internalLock: HRESULT; inline;
        begin
          with soundBuffer^.ManipulatableRegion do
          begin
           result := soundBuffer^.Content.Lock(
                                               (LPDWORD(ToLock.Start))^, ToLock.Size,
                                                @ManipulatedRegions[0].Start, @ManipulatedRegions[0].Size,
                                                @ManipulatedRegions[1].Start, @ManipulatedRegions[1].Size, 0
                                               );
          end;
        end;
      {$EndRegion NESTED ROUTINES}
      var code: HRESULT;
      begin
        soundBuffer^.ManipulatableRegion.ToLock := computedRegion;
        code := internalLock;
        IndentifyLockInfo(code);
      end;

      procedure WriteSamplesTolockedRegion(const lockedRegion: TRegion; var wavePos: TSine; var globalSampleIndex: TInfiniteSampleIndex);
      var
        totalSampleCount, SampleIndex: TSampleIndex;
        firstSample: PSampleChannels;
        volume: TSoundVolume;

        function sineVolume: TSoundVolume; inline;
        var sinus: TSine;
        begin
          sinus := TSine(sin(wavePos));
          result := TSoundVolume(Trunc(sinus * TSampleInfo.CHANNELVOLUME));
          wavePos += TSine((TWaveCycle.DURATION * 1.0) / TSine(TSampleInfo.SAMPLESPERWAVECYCLE));
        end;

      begin
        if lockedRegion.Size = 0 then exit;

        totalSampleCount := TSampleIndex(lockedRegion.Size div TSampleInfo.SIZE) - 1;

        firstSample := PSampleChannels(lockedRegion.Start);

        for SampleIndex := 0 to totalSampleCount do
        begin
          volume := sineVolume;
          firstSample^.Left := volume;
          firstSample^.Right := volume;
          inc(firstSample);
          inc(globalSampleIndex);
        end;
      end;
      {PRIVATE}


      {PUBLIC}
      function EnableSoundProcessing(const hwnd: HWND): boolean;
      begin
        result := (DirectSoundCreate8(nil, DS8, nil) >= 0);
        result := result and (Ds8.SetCooperativeLevel(hwnd, DSSCL_PRIORITY) >= 0);
      end;

      procedure CreateSoundBuffer(var soundBuffer: TSoundBuffer);
      var
        bufferCreated: boolean;
        bfdesc : DSBUFFERDESC;
        wFormat: WAVEFORMATEX;
      begin
        wFormat := Default(WAVEFORMATEX);
        wFormat.cbSize := 0;
        wFormat.wFormatTag := WAVE_FORMAT_PCM;
        wFormat.nChannels := TSampleInfo.CHANNELCOUNT;
        wFormat.nSamplesPerSec := TSampleInfo.SAMPLESPERSECOND;
        wFormat.wBitsPerSample := TSampleInfo.SAMPLEBITS;
        wFormat.nBlockAlign := Word((TSampleInfo.CHANNELCOUNT * TSampleInfo.SAMPLEBITS) div 8);
        wFormat.nAvgBytesPerSec := WFORMAT.nBlockAlign * WFORMAT.nSamplesPerSec;

        bfdesc := Default(DSBUFFERDESC);
        bfdesc.dwSize := sizeOf(DSBUFFERDESC);
        bfdesc.dwBufferBytes := high(TBufferSize);
        bfdesc.dwFlags := 0;
        bfdesc.lpwfxFormat:= @wFormat;

        soundBuffer := Default(TSoundBuffer);
        soundBuffer.Playing := false;
        soundBuffer.GlobalSampleIndex := 0;
        soundBuffer.WavePosition := 0.0;

        with soundBuffer.ManipulatableRegion do
        begin
          ToLock := Default(TRegion);
          ManipulatedRegions[0] := Default(TRegion);
          ManipulatedRegions[1] := Default(TRegion);
          Cursor.PlayCursor := DEFAULT_CURSOR_POS;
          Cursor.WriteCursor := DEFAULT_CURSOR_POS;
          Cursor.TargetCursor := DEFAULT_CURSOR_POS;

          with soundBuffer.ManipulatableRegion.ManipulatedRegionState do
          begin
           LockState.infoAfterLock := Default(TAfterCallData);
           LockState.infoAfterLock.CallSuceeded := false;
           LockState.infoAfterLock.FunctionName := '<LOCK>';
           LockState.infoAfterLock.Number := 0;

           UnlockState.infoAfterUnlock := Default(TAfterCallData);
           UnlockState.infoAfterUnlock.CallSuceeded := false;
           UnlockState.infoAfterUnlock.FunctionName := '<UNLOCK>';
           UnlockState.infoAfterUnlock.Number := 0;
          end;
        end;

        bufferCreated := DS8.CreateSoundBuffer(bfdesc, soundBuffer.Content, nil) >= 0;

        if not bufferCreated then raise Exception.Create('Somehow the Creation of soundBuffer didnt work properly');
      end;

      procedure WriteSamplesToSoundBuffer(const soundBuffer: PSoundBuffer);
      var state: string;
      begin
        with soundBuffer^.ManipulatableRegion do
        begin
          with soundBuffer^.ManipulatableRegion.ManipulatedRegionState do
          begin
            LockRegionsWithin(soundBuffer);

            if not soundBuffer^.Playing then
              PrintLockState(@LockState);

            if not LockState.infoAfterLock.CallSuceeded then exit;

            (*-LockedRegion1-*)
            WriteSamplesTolockedRegion(ManipulatedRegions[0], soundBuffer^.WavePosition, soundBuffer^.GlobalSampleIndex);

            (*-LockedRegion2-*)
            WriteSamplesTolockedRegion(ManipulatedRegions[1], soundBuffer^.WavePosition, soundBuffer^.GlobalSampleIndex);

            UnlockRegionsWithin(soundBuffer);

            //Print(@UnlockState);
          end;
        end;
      end;

      procedure PlayTheSoundBuffer(const soundBuffer: PSoundBuffer); inline;
      begin
        if not soundBuffer^.Playing then
          soundBuffer^.Playing := soundBuffer^.Content.Play(0, 0, DSBPLAY_LOOPING) >= 0;
      end;
      {PUBLIC}
  end.
