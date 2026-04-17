# Voice Record ITMO

Оффлайн iOS-приложение для записи голоса, транскрибации речи и генерации краткой сводки.

Состояние `README` актуально для текущего кода в репозитории.

## Что есть сейчас

- Запись аудио (`AVAudioRecorder`) с паузой/продолжением.
- Список записей с:
  - фильтрами (`All`, `Today`, `This Week`, `Starred`);
  - поиском по названию, транскрипции и summary;
  - быстрым воспроизведением из списка;
  - отметкой избранного.
- Экран записи:
  - таймер и визуальное состояние записи;
  - задание названия записи;
  - установка флага избранного.
- Экран детали:
  - плеер (play/pause, seek в начало/конец, `±15s`, скорость `0.5x...2.0x`);
  - вкладки `Transcript` и `Summary`;
  - копирование текста;
  - удаление записи;
  - share summary через системный share sheet.
- Полностью локальный AI-пайплайн:
  - транскрибация через `WhisperKit`;
  - суммаризация через локальную LLM (`qwen2.5-1.5b-instruct-q4_k_m.gguf` + `llama.swift`).
- Прогресс AI-этапов в UI (`loading models`, `preprocessing`, `transcribing`, `summarizing`, `done/error`).
- Локализация интерфейса: `ru` и `en`.

## Текущий стек

- Язык: `Swift 5`.
- UI: `SwiftUI` в `UIHostingController` + `UINavigationController` (не чистый UIKit).
- Аудио: `AVFoundation`.
- AI:
  - `WhisperKit` (`0.15.0`) для распознавания;
  - `LlamaSwift` из `llama.swift` (`2.7642.0`) для summary.
- Хранение:
  - аудио: `Documents/Recordings`;
  - metadata JSON: `Documents/RecordingMetadata`.
- Тесты: Swift Testing (`import Testing`) в `voice_record_itmoTests`.

## Архитектура (по текущим файлам)

- `AppDelegate` поднимает `UINavigationController` и `Main` экран.
- `UI/`:
  - `Main` — список/поиск/фильтры/быстрый плеер;
  - `NewRecording` — запись;
  - `Detail` — плеер + transcript/summary.
- `Domain/`:
  - `RecordingService` — запись/воспроизведение;
  - `FileManagerService` — работа с аудиофайлами;
  - `MetaDataFileManager` — JSON metadata;
  - `FileManagerFacade` — склейка audio + metadata;
  - `AiFacade` + `WhisperService` + `QwenLlamaService`.

## Локальные модели и ресурсы

Для работы AI в бандле приложения должны быть ресурсы:

- `openai_whisper-small/`:
  - `AudioEncoder.mlmodelc`
  - `MelSpectrogram.mlmodelc`
  - `TextDecoder.mlmodelc`
  - `config.json`
  - `generation_config.json`
- `qwen2.5-1.5b-instruct-q4_k_m.gguf`

В проекте эти файлы уже подключены в `Resources` target-а `voice_record_itmo`.

## Требования

- Xcode с iOS 18 SDK (в проекте `IPHONEOS_DEPLOYMENT_TARGET = 18.0`).
- iOS 18+ устройство (для записи нужен доступ к микрофону).
- Свободная память/диск под локальные модели (LLM-файл большой).

## Как запустить

1. Открыть `voice_record_itmo.xcodeproj`.
2. Проверить, что большие AI-ресурсы присутствуют в проекте (см. раздел выше).
3. Выбрать target `voice_record_itmo` и реальное iOS-устройство.
4. Запустить приложение.
5. При первом старте дать доступ к микрофону.

## Что важно знать

- `README` раньше описывал старую версию (NaturalLanguage/RecordViewController), сейчас это не соответствует коду.
- Суммаризация выполняется не через `NaturalLanguage`, а через локальную Qwen-модель.
