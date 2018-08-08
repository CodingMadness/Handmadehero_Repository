Unit GameSound;

  {$modeswitch advancedrecords}

  INTERFACE
      USES
        Windows, classes, Helper, mmsystem, sysutils, DirectSound, crt;

      const
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

        TSoundVolume = -TSampleInfo.CHANNELVOLUME..TSampleInfo.CHANNELVOLUME;

        TSine = Single;

        TSampleChannels = record
          Left, Right: TSoundVolume;
        end;

        PSampleChannels = ^TSampleChannels;

        TSampleIndex =  0..(TSampleInfo.SAMPLESPERSECOND-1);

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

        TLockableRegion = record
         ToLock: TRegion;
         LockedRegions: array[0..1] of TRegion;
         Cursor: TSystemCursor;
         StateAfterLock, StateAfterUnlock: TLockState;
        end;

        TSoundBuffer = record
          Playing: BOOL;
          WavePosition: TSine;
          Content: IDirectSoundBuffer;
          GlobalSampleIndex: TSampleIndex;
          LockableRegion: TLockableRegion;
        end;

        PSoundBuffer = ^TSoundBuffer;

      function EnableSoundProcessing(const hwnd: HWND): BOOL;
      procedure CreateSoundBuffer(var soundBuffer: TSoundBuffer);
      procedure WriteSamplesToSoundBuffer(const soundBuffer: PSoundBuffer);
      procedure PlayTheSoundBuffer(const soundBuffer: PSoundBuffer);

  IMPLEMENTATION
      var
        DS8: IDIRECTSOUND8;

      {PRIVATE}
      procedure UnlockRegionsWithin(const soundBuffer: PSoundBuffer);
        procedure DefineUnlockState(const code: HRESULT);
        begin
          with soundBuffer^.LockableRegion do
          begin
            StateAfterLock.Locked := (code < 0);

            if StateAfterLock.Locked then
              StateAfterLock.FailureCount += 1
            else
              StateAfterLock.SuccessCount += 1;

            StateAfterLock.Message := GetFunctionReturnMessage(code);
          end;
        end;
      var
        tmp: HRESULT;
      begin
        with soundBuffer^.LockableRegion do
        begin
          tmp := soundBuffer^.Content.Unlock(LockedRegions[0].Start, LockedRegions[0].Size, LockedRegions[1].Start, LockedRegions[1].Size);
          DefineUnlockState(tmp);
        end;
      end;

      procedure LockRegionsWithin(const soundBuffer: PSoundBuffer);
        function specificRegion: TRegion;
        var first: DWORD = 0;
        begin
          result.Start := LPVOID(@first);
          result.Size := TSampleInfo.LATENCYSAMPLECOUNT;
        end;

        function computedRegion: TRegion;
        var
          positionValid: boolean;
          StartByteToLockFrom: TBufferSize;
          nrOfBytesToLock: TBufferSize = 0;
        begin
          with soundBuffer^.LockableRegion.Cursor do
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

        procedure DefineLockState(const code: HRESULT);
        begin
          with soundBuffer^.LockableRegion do
          begin
            StateAfterLock.Locked := (code >= 0);

            if StateAfterLock.Locked then
              StateAfterLock.SuccessCount += 1
            else
              StateAfterLock.FailureCount += 1;

            StateAfterLock.Message := GetFunctionReturnMessage(code);
          end;
        end;

        function DoInternalLock: HRESULT;
        begin
          with soundBuffer^.LockableRegion do
          begin
           result := soundBuffer^.Content.Lock( (LPDWORD(ToLock.Start))^, ToLock.Size,
                                              @LockedRegions[0].Start, @LockedRegions[0].Size,
                                              @LockedRegions[1].Start, @LockedRegions[1].Size, 0
                                            );

          end;
        end;

      var code: HRESULT;
      begin
        if not soundBuffer^.Playing then
          soundBuffer^.LockableRegion.ToLock := specificRegion

        else
          soundBuffer^.LockableRegion.ToLock := computedRegion;

        code := DoInternalLock;

        DefineLockState(code);
      end;

      procedure WriteSamplesTolockedRegion(const lockedRegion: TRegion; var wavePos: TSine; var globalSampleIndex: TSampleIndex);
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
      function EnableSoundProcessing(const hwnd: HWND): BOOL;
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
        wFormat := default(WAVEFORMATEX);
        wFormat.cbSize := 0;
        wFormat.wFormatTag := WAVE_FORMAT_PCM;
        wFormat.nChannels := TSampleInfo.CHANNELCOUNT;
        wFormat.nSamplesPerSec := TSampleInfo.SAMPLESPERSECOND;
        wFormat.wBitsPerSample := TSampleInfo.SAMPLEBITS;
        wFormat.nBlockAlign := Word((TSampleInfo.CHANNELCOUNT * TSampleInfo.SAMPLEBITS) div 8);
        wFormat.nAvgBytesPerSec := WFORMAT.nBlockAlign * WFORMAT.nSamplesPerSec;

        bfdesc := default(DSBUFFERDESC);
        bfdesc.dwSize := sizeOf(DSBUFFERDESC);
        bfdesc.dwBufferBytes := high(TBufferSize);
        bfdesc.dwFlags := 0;
        bfdesc.lpwfxFormat:= @wFormat;

        soundBuffer := default(TSoundBuffer);
        soundBuffer.Playing := false;
        soundBuffer.GlobalSampleIndex := 0;
        soundBuffer.WavePosition := 0.0;

        with soundBuffer.LockableRegion do
        begin
          ToLock := default(TRegion);
          LockedRegions[0] := default(TRegion);
          LockedRegions[1] := default(TRegion);
          Cursor.PlayCursor := DEFAULT_CURSOR_POS;
          Cursor.WriteCursor := DEFAULT_CURSOR_POS;
          Cursor.TargetCursor := DEFAULT_CURSOR_POS;
          StateAfterLock := default(TLockState);
          StateAfterUnlock := default(TLockState);
        end;

        bufferCreated := DS8.CreateSoundBuffer(bfdesc, soundBuffer.Content, nil) >= 0;

        if not bufferCreated then raise Exception.Create('Somehow the Creation of soundBuffer didnt work properly');
      end;

      procedure WriteSamplesToSoundBuffer(const soundBuffer: PSoundBuffer);
      begin
        with soundBuffer^.LockableRegion do
        begin
          LockRegionsWithin(soundBuffer);

          //if not soundBuffer^.Playing then
          PrintLockState(@StateAfterLock, 'Lock');

          if not StateAfterLock.Locked then exit;

          (*-LockedRegion1-*)
          WriteSamplesTolockedRegion(LockedRegions[0], soundBuffer^.WavePosition, soundBuffer^.GlobalSampleIndex);

          (*-LockedRegion2-*)
          WriteSamplesTolockedRegion(LockedRegions[1], soundBuffer^.WavePosition, soundBuffer^.GlobalSampleIndex);

          UnlockRegionsWithin(soundBuffer);

          (*PrintLockState(@StateAfterunlock, 'Unlock');*)
        end;
      end;

      procedure PlayTheSoundBuffer(const soundBuffer: PSoundBuffer); inline;
      begin
        if not soundBuffer^.Playing then
          soundBuffer^.Playing := soundBuffer^.Content.Play(0, 0, DSBPLAY_LOOPING) >= 0;
      end;
      {PUBLIC}
  end.
