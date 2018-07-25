Unit GameSound;

{$modeswitch advancedrecords}

  INTERFACE
      USES
        Windows, mmsystem, sysutils, DirectSound;

      TYPE
        TWaveCycle = record
          const WAVEFREQUENCY = 256; //1-HZ=256
          const HALFWAVEFREQUENCY = WAVEFREQUENCY div 2; //0.5 HZ = 128
          const DURATION = 2.0 * PI;
        end;

        TSampleInfo = record
          const SAMPLESPERSECOND = 48000;  //48khz
          const SAMPLESPERWAVECYCLE = SAMPLESPERSECOND div TWaveCycle.WAVEFREQUENCY;
          const SIZE = 4;

          const CHANNELCOUNT = 2;
          const CHANNELVOLUME = 9000(*Int16.MaxValue div 2*);
        end;

        TSoundVolume = -TSampleInfo.CHANNELVOLUME..TSampleInfo.CHANNELVOLUME;

        TSampleChannels = record
          Left, Right: TSoundVolume;
        end;

        PSampleChannels = ^TSampleChannels;

        TSampleIndex = 0..(TSampleInfo.SAMPLESPERSECOND-1);

        TBufferSize  =  0..(TSampleInfo.SAMPLESPERSECOND * TSampleInfo.SIZE);

        TRegion = packed record
         Start: LPVOID;
         Size: TBufferSize;
       end;

        TLockableRegion = record
         ToLock: TRegion;
         LockedRegions: array[0..1] of TRegion;
         &Locked, Unlocked: BOOL;
         SystemPlayCursor: DWORD;
        end;

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
        var DS8: IDIRECTSOUND8;

        function internal_lock(const soundBuffer: PSoundBuffer): HRESULT;
          var lockingSucceed: boolean;
        begin
          result := soundBuffer^.Content.Lock
          (
            (LPDWORD(soundBuffer^.LockableRegion.ToLock.Start))^, soundBuffer^.LockableRegion.ToLock.Size,
            @soundBuffer^.LockableRegion.LockedRegions[0].Start, @soundBuffer^.LockableRegion.LockedRegions[0].Size,
            @soundBuffer^.LockableRegion.LockedRegions[1].Start, @soundBuffer^.LockableRegion.LockedRegions[1].Size,
            0
          );

          lockingSucceed := (result >= 0);
          soundBuffer^.LockableRegion.Locked := lockingSucceed;
          soundBuffer^.LockableRegion.Unlocked := (not lockingSucceed);
        end;

        function internal_unlock(const soundBuffer: PSoundBuffer): HRESULT;
        var unlockingSucceed: boolean;
        begin
          result := soundBuffer^.Content.Unlock
          (
            soundBuffer^.LockableRegion.LockedRegions[0].Start, soundBuffer^.LockableRegion.LockedRegions[0].Size,
            soundBuffer^.LockableRegion.LockedRegions[1].Start, soundBuffer^.LockableRegion.LockedRegions[1].Size
          );

          unlockingSucceed := (result >= 0);
          soundBuffer^.LockableRegion.Unlocked := unlockingSucceed;
          soundBuffer^.LockableRegion.Locked := (not unlockingSucceed);
        end;

        function LockRegion(const soundBuffer: PSoundBuffer): BOOL;
          var firstByte: Byte = 0;
          var wholeBuffer: TRegion;
          var locked: boolean = false;

          function ComputeRegionToLock: TRegion;
            var positionValid: boolean;
            var StartByteToLockFrom, playCursor: DWORD;
            var nrOfBytesToWrite: TBufferSize = 0;
          begin
            positionValid := soundBuffer^.Content.GetCurrentPosition(@soundBuffer^.LockableRegion.SystemPlayCursor, nil) >= 0;

            if not positionValid then
            begin
              result.Size := 0;
              result.Start := nil;
              exit;
            end;

            StartByteToLockFrom := (soundBuffer^.RunningSampleIndex * TSampleInfo.SIZE) mod high(TBufferSize);

            playCursor := soundBuffer^.LockableRegion.SystemPlayCursor;

            if StartByteToLockFrom < playCursor then
              nrOfBytesToWrite := (playCursor - StartByteToLockFrom)

            else if StartByteToLockFrom > playCursor then
              nrOfBytesToWrite := (high(TBufferSIZE) - StartByteToLockFrom) + playCursor;

            result.Size := nrOfBytesToWrite;
            result.Start := LPVOID(@StartByteToLockFrom);
          end;
        begin
          if not soundBuffer^.Playing then
          begin
            wholeBuffer.Start := LPVOID(@firstByte);
            wholeBuffer.Size := high(TBufferSIZE);
            soundBuffer^.LockableRegion.ToLock := wholeBuffer;
          end

          else
            soundBuffer^.LockableRegion.ToLock := ComputeRegionToLock;

          if soundBuffer^.LockableRegion.Unlocked then
            locked := internal_lock(soundBuffer) >= 0;

          result := locked;
        end;

        procedure WriteSamplesTolockedRegion(const lockedRegion: TRegion; var runningSampleIndex: TSampleIndex);
          var totalSampleCount: TSampleIndex = 0;
          var firstSample: PSampleChannels;
          var volume: TSoundVolume;
          var SampleIndex: TSampleIndex;

          function get_sineWaveVolume: TSoundVolume;
          var time, sinus: real;
          begin
            time := TWaveCycle.DURATION * Real(runningSampleIndex) / Real(TSampleInfo.SAMPLESPERWAVECYCLE);
            sinus := Real(sin(time));
            result := TSoundVolume(Trunc(sinus * TSampleInfo.CHANNELVOLUME));
          end;

          function get_squareWaveVolume: TSoundVolume;
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

          totalSampleCount := TSampleIndex(Trunc(lockedRegion.Size / TSampleInfo.SIZE) - 1);

          firstSample := PSampleChannels(lockedRegion.Start);

          for SampleIndex := 0 to totalSampleCount do
          begin
            volume := get_sineWaveVolume;
            firstSample^.Left := volume;
            firstSample^.Right := volume;
            inc(firstSample);
            inc(runningSampleIndex);
          end;
        end;

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
          bfdesc.lpwfxFormat:= @WFORMAT;

          soundBuffer := default(TSoundBuffer);
          soundBuffer.Playing := false;
          soundBuffer.LockableRegion.Unlocked := true;
          soundBuffer.LockableRegion.Locked := false;

          bufferCreated := DS8.CreateSoundBuffer(bfdesc, soundBuffer.Content, nil) >= 0;

          if not bufferCreated then raise Exception.Create('Somehow the Creation of soundBuffer didnt work properly');
        end;

        procedure WriteSamplesToSoundBuffer(const soundBuffer: PSoundBuffer);
          var locked: boolean = false;
          var unlocked: boolean = false;
        begin
          locked := LockRegion(soundBuffer);

          if not &locked then
            raise Exception.Create('The buffer wasnt able to lock a specific lockedRegion for writing to it');

          (*LockedRegion1*)
          WriteSamplesTolockedRegion(soundBuffer^.LockableRegion.LockedRegions[0], soundBuffer^.RunningSampleIndex);

          (*LockedRegion2*)
          WriteSamplesTolockedRegion(soundBuffer^.LockableRegion.LockedRegions[1], soundBuffer^.RunningSampleIndex);

          if soundBuffer^.LockableRegion.Locked then
            unlocked := internal_unlock(soundBuffer) >= 0;

          if not unlocked then
            raise Exception.Create('The buffers lockedRegion he locked once for writing to it couldnt be unlocked again');
        end;

        procedure PlayTheSoundBuffer(const soundBuffer: PSoundBuffer);
        begin
          if not soundBuffer^.Playing then
            soundBuffer^.Playing := soundBuffer^.Content.Play(0, 0, DSBPLAY_LOOPING) >= 0;
        end;
end.
