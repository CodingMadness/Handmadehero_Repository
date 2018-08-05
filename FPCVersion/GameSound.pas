Unit GameSound;

  {$modeswitch advancedrecords}

  INTERFACE
      USES
        Windows, mmsystem, sysutils, DirectSound;

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

        //Change 1.
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

        TSampleChannels = record
          Left, Right: TSoundVolume;
        end;

        PSampleChannels = ^TSampleChannels;

        TSampleIndex = 0..(TSampleInfo.SAMPLESPERSECOND-1);

        TBufferSize  =  0..(TSampleInfo.SAMPLESPERSECOND * TSampleInfo.SIZE);

        TCursorPosition = DEFAULT_CURSOR_POS..high(DWORD);

        TReturnMessage = String[SENSEFUL_ERROR_LENGTH];

        TRegion = packed record
         Start: LPVOID;
         Size: TBufferSize;
       end;

        TRegionState = record
          Locked: BOOL;
          Message: TReturnMessage;
        end;

        {Change 2.}
        TSystemCursor = record
          PlayCursor,
          WriteCursor,
          TargetCursor: TCursorPosition;
        end;

        TLockableRegion = record
         ToLock: TRegion;
         LockedRegions: array[0..1] of TRegion;
         State: TRegionState;
         Cursor: TSystemCursor;
        end;
        {Change 2.}

        TSoundBuffer = record
          RunningSampleIndex: TSampleIndex;
          Playing: BOOL;
          Content: IDirectSoundBuffer;
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
      function CodeToErrorMsg(const errorCode: HRESULT): TReturnMessage;
      var
        messageBuffer: LPSTR;
      begin
        FormatMessageA(FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS,
                       nil, errorCode, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), LPSTR(@messageBuffer), 0, nil);

        result := TReturnMessage(messageBuffer);
      end;

      procedure UnlockRegionWithin(const soundBuffer: PSoundBuffer);
        var
          result: HRESULT;
      begin
        result := soundBuffer^.Content.Unlock
        (
          soundBuffer^.LockableRegion.LockedRegions[0].Start, soundBuffer^.LockableRegion.LockedRegions[0].Size,
          soundBuffer^.LockableRegion.LockedRegions[1].Start, soundBuffer^.LockableRegion.LockedRegions[1].Size
        );

        soundBuffer^.LockableRegion.State.Locked := (result < 0);
        soundBuffer^.LockableRegion.State.Message := CodeToErrorMsg(result);
      end;

      procedure LockRegionWithin(const soundBuffer: PSoundBuffer);
        //Change 3.
        function specificRegion: TRegion;
        var first: DWORD = 0;
        begin
          result.Start := LPVOID(@first);
          result.Size := TSampleInfo.LATENCYSAMPLECOUNT;
        end;

        //Change 4.
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
              TargetCursor := (TSampleInfo.LATENCYSAMPLEBYTECOUNT + PlayCursor) mod high(TBufferSize);
              StartByteToLockFrom := (soundBuffer^.RunningSampleIndex * TSampleInfo.SIZE) mod high(TBufferSize);

              if StartByteToLockFrom < TargetCursor then
                nrOfBytesToLock := TBufferSize(TargetCursor - StartByteToLockFrom)

              else if StartByteToLockFrom >= TargetCursor then
                nrOfBytesToLock := TBufferSize((high(TBufferSIZE) - StartByteToLockFrom) + TargetCursor);

              result.Size := nrOfBytesToLock;
              result.Start := LPVOID(@StartByteToLockFrom);
            end;
          end;
        end;

        procedure DoInternalLock;
          var result: HRESULT;
        begin
          result := soundBuffer^.Content.Lock
          (
            (LPDWORD(soundBuffer^.LockableRegion.ToLock.Start))^, soundBuffer^.LockableRegion.ToLock.Size,
            @soundBuffer^.LockableRegion.LockedRegions[0].Start, @soundBuffer^.LockableRegion.LockedRegions[0].Size,
            @soundBuffer^.LockableRegion.LockedRegions[1].Start, @soundBuffer^.LockableRegion.LockedRegions[1].Size,
            0
          );

          soundBuffer^.LockableRegion.State.Locked := (result >= 0);
          soundBuffer^.LockableRegion.State.Message := CodeToErrorMsg(result);
        end;
      begin
        if not soundBuffer^.Playing then
          soundBuffer^.LockableRegion.ToLock := specificRegion

        else
          //computedRegion raises an error due to wrong computation
          soundBuffer^.LockableRegion.ToLock := computedRegion;

        DoInternalLock;
      end;

      procedure WriteSamplesTolockedRegion(const lockedRegion: TRegion; var runningSampleIndex: TSampleIndex);
      var
        totalSampleCount, SampleIndex: TSampleIndex;
        firstSample: PSampleChannels;
        volume: TSoundVolume;

        function sine_wave: TSoundVolume;
        var time, sinus: real;
        begin
          time := TWaveCycle.DURATION * Real(runningSampleIndex) / Real(TSampleInfo.SAMPLESPERWAVECYCLE);
          sinus := Real(sin(time));
          result := TSoundVolume(Trunc(sinus * TSampleInfo.CHANNELVOLUME));
        end;

        function square_wave: TSoundVolume;
          var relativeSampleIndex: TSampleIndex;
        begin
          relativeSampleIndex := (runningSampleIndex div TWaveCycle.HALFWAVEFREQUENCY);
          if (relativeSampleIndex mod 2) = 0 then
            result := TSampleInfo.CHANNELVOLUME
          else
            result := -TSampleInfo.CHANNELVOLUME;
        end;
      begin
        if lockedRegion.Size = 0 then exit;

        totalSampleCount := TSampleIndex(lockedRegion.Size div TSampleInfo.SIZE) - 1;

        firstSample := PSampleChannels(lockedRegion.Start);

        for SampleIndex := 0 to totalSampleCount do
        begin
          volume := sine_wave;
          firstSample^.Left := volume;
          firstSample^.Right := volume;
          inc(firstSample);
          inc(runningSampleIndex);
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
        wFormat.nBlockAlign := Word(Round((WFORMAT.nChannels * WFORMAT.wBitsPerSample) / 8));
        wFormat.nAvgBytesPerSec := WFORMAT.nBlockAlign * WFORMAT.nSamplesPerSec;

        bfdesc := default(DSBUFFERDESC);
        bfdesc.dwSize := sizeOf(DSBUFFERDESC);
        bfdesc.dwBufferBytes := high(TBufferSize);
        bfdesc.dwFlags := 0;
        bfdesc.lpwfxFormat:= @wFormat;

        soundBuffer := default(TSoundBuffer);
        soundBuffer.Playing := false;
        soundBuffer.RunningSampleIndex := 0;
        soundBuffer.LockableRegion.Cursor.PlayCursor := DEFAULT_CURSOR_POS;
        soundBuffer.LockableRegion.Cursor.WriteCursor := DEFAULT_CURSOR_POS;
        soundBuffer.LockableRegion.Cursor.TargetCursor := DEFAULT_CURSOR_POS;
        soundBuffer.LockableRegion.State.Locked   := false;
        soundBuffer.LockableRegion.State.Message := 'NONE';

        bufferCreated := DS8.CreateSoundBuffer(bfdesc, soundBuffer.Content, nil) >= 0;

        if not bufferCreated then raise Exception.Create('Somehow the Creation of soundBuffer didnt work properly');
      end;

      procedure WriteSamplesToSoundBuffer(const soundBuffer: PSoundBuffer);
      begin
        LockRegionWithin(soundBuffer);

        if not soundBuffer^.LockableRegion.State.Locked then
          raise Exception.Create('The specified region could not be locked because of: ' + soundBuffer^.LockableRegion.State.Message);

        (*LockedRegion1*)
        WriteSamplesTolockedRegion(soundBuffer^.LockableRegion.LockedRegions[0], soundBuffer^.RunningSampleIndex);

        (*LockedRegion2*)
        WriteSamplesTolockedRegion(soundBuffer^.LockableRegion.LockedRegions[1], soundBuffer^.RunningSampleIndex);

        UnlockRegionWithin(soundBuffer);

        if soundBuffer^.LockableRegion.State.Locked then
          raise Exception.Create('The specified region could not be unlocked because of: ' + soundBuffer^.LockableRegion.State.Message);
      end;

      procedure PlayTheSoundBuffer(const soundBuffer: PSoundBuffer);
      begin
        if not soundBuffer^.Playing then
          soundBuffer^.Playing := soundBuffer^.Content.Play(0, 0, DSBPLAY_LOOPING) >= 0;
      end;
      {PUBLIC}
  end.
