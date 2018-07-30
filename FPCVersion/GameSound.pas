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

        TSampleInfo = record
          const SIZE = 4;
          const CHANNELCOUNT = 2;
          const CHANNELVOLUME = 10000;
          const SAMPLESPERSECOND = 48000;
          const SAMPLESPERWAVECYCLE = SAMPLESPERSECOND div TWaveCycle.WAVEFREQUENCY;
        end;

        TSoundVolume = -TSampleInfo.CHANNELVOLUME..TSampleInfo.CHANNELVOLUME;

        TSampleChannels = record
          Left, Right: TSoundVolume;
        end;

        PSampleChannels = ^TSampleChannels;

        TSampleIndex =  0..(TSampleInfo.SAMPLESPERSECOND-1);

        TBufferSize  =  0..(TSampleInfo.SAMPLESPERSECOND * TSampleInfo.SIZE);

        TValidCursorPos = DEFAULT_CURSOR_POS..high(DWORD);

        T_ERRORMSG = String[SENSEFUL_ERROR_LENGTH];

        TRegion = packed record
         Start: LPVOID;
         Size: TBufferSize;
       end;

        TRegionState = record
          Locked: BOOL;
          ErrorMsg: T_ERRORMSG;
        end;

        TLockableRegion = record
         ToLock: TRegion;
         LockedRegions: array[0..1] of TRegion;
         State: TRegionState;
         SystemPlayCursor, SystemWriteCursor: TValidCursorPos;
        end;

        WIN32SOUNDBUFFER = IDirectSoundBuffer;

        TSoundBuffer = record
          RunningSampleIndex: TSampleIndex;
          Playing: BOOL;
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
        DS8: IDIRECTSOUND8;

      {PRIVATE}
      function CodeToErrorMsg(const errorCode: HRESULT): T_ERRORMSG;
      var
        messageBuffer: LPSTR;
      begin
        FormatMessageA(FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS,
                       nil, errorCode, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), LPSTR(@messageBuffer), 0, nil);

        result := T_ERRORMSG(messageBuffer);
      end;

      procedure UnlockRegion(const soundBuffer: PSoundBuffer);
        var
          result: HRESULT;
      begin
        result := soundBuffer^.Content.Unlock
        (
          soundBuffer^.LockableRegion.LockedRegions[0].Start, soundBuffer^.LockableRegion.LockedRegions[0].Size,
          soundBuffer^.LockableRegion.LockedRegions[1].Start, soundBuffer^.LockableRegion.LockedRegions[1].Size
        );

        soundBuffer^.LockableRegion.State.Locked := (result < 0);
        soundBuffer^.LockableRegion.State.ErrorMsg := CodeToErrorMsg(result);
      end;

      procedure LockRegion(const soundBuffer: PSoundBuffer);
        function compute_region_toLock: TRegion;
          var
            positionValid: boolean;
            StartByteToLockFrom, playCursor, writeCursor: TBufferSize;
            nrOfBytesToWrite: TBufferSize = 0;
        begin
          positionValid := soundBuffer^.Content.
                                        GetCurrentPosition
                                        (@soundBuffer^.LockableRegion.SystemPlayCursor,
                                         @soundBuffer^.LockableRegion.SystemWriteCursor
                                        ) >= 0;

          if not positionValid then
          begin
            result.Size := 0;
            result.Start := nil;
            exit;
          end;

          StartByteToLockFrom := (soundBuffer^.RunningSampleIndex * TSampleInfo.SIZE) mod high(TBufferSize);

          playCursor := soundBuffer^.LockableRegion.SystemPlayCursor;
          writeCursor := soundBuffer^.LockableRegion.SystemWriteCursor;
          {$region Buffer allocation bug here}

          if StartByteToLockFrom < playCursor then
            nrOfBytesToWrite := (playCursor - StartByteToLockFrom)

          else if StartByteToLockFrom > playCursor then
            nrOfBytesToWrite := (high(TBufferSIZE) - StartByteToLockFrom) + playCursor

          else if StartByteToLockFrom = playCursor then
            nrOfBytesToWrite := (high(TBufferSIZE) - playCursor);

          {$endregion}

          result.Size := nrOfBytesToWrite;
          result.Start := LPVOID(@StartByteToLockFrom);
        end;

        function get_whole_buffer: TRegion; inline;
        var
          firstByte: Byte = 0;
        begin
          result.Start := @firstByte;
          result.Size := high(TBufferSIZE);
        end;

        procedure internal_lock; inline;
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
          soundBuffer^.LockableRegion.State.ErrorMsg := CodeToErrorMsg(result);
        end;
      begin
        if not soundBuffer^.Playing then
          soundBuffer^.LockableRegion.ToLock := get_whole_buffer

        else
          soundBuffer^.LockableRegion.ToLock := compute_region_toLock;

        internal_lock;
      end;

      procedure WriteSamplesTolockedRegion(const lockedRegion: TRegion; var runningSampleIndex: TSampleIndex);
        var
         totalSampleCount: TSampleIndex = 0;
         firstSample: PSampleChannels;
         volume: TSoundVolume;
         SampleIndex: TSampleIndex;

        function get_sine_volume: TSoundVolume; inline;
        var time, sinus: real;
        begin
          time := TWaveCycle.DURATION * Real(runningSampleIndex) / Real(TSampleInfo.SAMPLESPERWAVECYCLE);
          sinus := Real(sin(time));
          result := TSoundVolume(Trunc(sinus * TSampleInfo.CHANNELVOLUME));
        end;

        function get_square_volume: TSoundVolume; inline;
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

        totalSampleCount := TSampleIndex(Round(lockedRegion.Size / TSampleInfo.SIZE) - 1);

        firstSample := PSampleChannels(lockedRegion.Start);

        for SampleIndex := 0 to totalSampleCount do
        begin
          volume := get_sine_volume;
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
        soundBuffer.LockableRegion.SystemPlayCursor := DEFAULT_CURSOR_POS;
        soundBuffer.LockableRegion.State.Locked   := false;
        soundBuffer.LockableRegion.State.ErrorMsg := 'NONE';

        bufferCreated := DS8.CreateSoundBuffer(bfdesc, soundBuffer.Content, nil) >= 0;

        if not bufferCreated then raise Exception.Create('Somehow the Creation of soundBuffer didnt work properly');
      end;

      procedure WriteSamplesToSoundBuffer(const soundBuffer: PSoundBuffer);
      begin
        LockRegion(soundBuffer);

        if not soundBuffer^.LockableRegion.State.Locked then
          raise Exception.Create('The specified region could not be locked because of: ' + soundBuffer^.LockableRegion.State.ErrorMsg);

        (*LockedRegion1*)
        WriteSamplesTolockedRegion(soundBuffer^.LockableRegion.LockedRegions[0], soundBuffer^.RunningSampleIndex);

        (*LockedRegion2*)
        WriteSamplesTolockedRegion(soundBuffer^.LockableRegion.LockedRegions[1], soundBuffer^.RunningSampleIndex);

        UnlockRegion(soundBuffer);

        if soundBuffer^.LockableRegion.State.Locked then
          raise Exception.Create('The specified region could not be unlocked because of: ' + soundBuffer^.LockableRegion.State.ErrorMsg);
      end;

      procedure PlayTheSoundBuffer(const soundBuffer: PSoundBuffer);
      begin
        if not soundBuffer^.Playing then
          soundBuffer^.Playing := soundBuffer^.Content.Play(0, 0, DSBPLAY_LOOPING) >= 0;
      end;
      {PUBLIC}
  end.
