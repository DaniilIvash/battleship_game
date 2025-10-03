import 'dart:io';
import 'dart:math';
import 'dart:async'; // Для задержки

// КОНСТАНТЫ
const int BOARD_SIZE = 10;
const List<int> SHIP_LENGTHS = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1];
const String EMPTY_CELL = '~';
const String SHIP_CELL = '#';
const String HIT_CELL = 'X';
const String MISS_CELL = 'O';
const String SUNK_CELL = '*';

// ГЛАВНАЯ ФУНКЦИЯ
void main() {
  print('=== МОРСКОЙ БОЙ ===');
  print('Выберите режим:');
  print('1. Игрок vs Компьютер');
  print('2. Игрок vs Игрок');
  stdout.write('> ');
  final mode = int.tryParse(stdin.readLineSync()!) ?? 1;

  final player1 = Player(human: true, name: 'Игрок 1');
  final player2 = mode == 1
      ? Player(human: false, name: 'Компьютер')
      : Player(human: true, name: 'Игрок 2');

  playGame(player1, player2);
}

// КЛАСС ИГРОКА
class Player {
  final String name;
  final bool human;
  late List<List<String>> board;
  late List<List<String>> enemyView;
  int hits = 0;
  int misses = 0;
  List<Map<String, int>> lastHits = [];

  Player({required this.name, required this.human}) {
    board = List.generate(BOARD_SIZE, (_) => List.filled(BOARD_SIZE, EMPTY_CELL));
    enemyView = List.generate(BOARD_SIZE, (_) => List.filled(BOARD_SIZE, EMPTY_CELL));
    _placeShipsRandomly();
  }

  // РАССТАНОВКА КОРАБЛЕЙ
  void _placeShipsRandomly() {
    for (final length in SHIP_LENGTHS) {
      bool placed = false;
      while (!placed) {
        final isHorizontal = Random().nextBool();
        final x = Random().nextInt(BOARD_SIZE);
        final y = Random().nextInt(BOARD_SIZE);
        if (_canPlaceShip(x, y, length, isHorizontal)) {
          _placeShip(x, y, length, isHorizontal);
          placed = true;
        }
      }
    }
  }

  bool _canPlaceShip(int x, int y, int length, bool isHorizontal) {
    if (isHorizontal && x + length > BOARD_SIZE) return false;
    if (!isHorizontal && y + length > BOARD_SIZE) return false;

    for (int i = -1; i <= length; i++) {
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          final nx = x + (isHorizontal ? i : 0) + dx;
          final ny = y + (isHorizontal ? 0 : i) + dy;
          if (nx >= 0 && nx < BOARD_SIZE && ny >= 0 && ny < BOARD_SIZE) {
            if (board[ny][nx] == SHIP_CELL) return false;
          }
        }
      }
    }
    return true;
  }

  void _placeShip(int x, int y, int length, bool isHorizontal) {
    for (int i = 0; i < length; i++) {
      final nx = x + (isHorizontal ? i : 0);
      final ny = y + (isHorizontal ? 0 : i);
      board[ny][nx] = SHIP_CELL;
    }
  }

  // ХОД ИГРОКА
  String makeMove(Player enemy) {
    print('\n--- Ход $name ---');
    _printBoards(enemy);

    int x, y;
    if (human) {
      while (true) {
        stdout.write('Введите координаты (например, A5): ');
        final input = stdin.readLineSync()!.toUpperCase();
        if (input.length < 2) {
          print('❌ Некорректный ввод! Пример: A5');
          continue;
        }
        x = input.codeUnitAt(0) - 65;
        y = int.tryParse(input.substring(1)) ?? -1;
        if (x < 0 || x >= BOARD_SIZE || y < 1 || y >= BOARD_SIZE + 1) {
          print('❌ Координаты вне поля! Диапазон: A1-J10');
        } else if (enemy.enemyView[y - 1][x] != EMPTY_CELL) {
          print('❌ Сюда уже стреляли! (${String.fromCharCode(65 + x)}$y)');
          final cell = enemy.enemyView[y - 1][x];
          print('  Там сейчас: ${cell == HIT_CELL ? "ПОПАДАНИЕ (X)" : "ПРОМАХ (O)"}');
        } else {
          y--;
          break;
        }
      }
    } else {
      print('Компьютер думает...');
      sleep(const Duration(seconds: 2)); // Пауза 2 секунды
      final target = _aiChooseTarget(enemy);
      x = target['x']!;
      y = target['y']!;
      print('Компьютер стреляет в ${String.fromCharCode(65 + x)}${(y + 1)}');
    }

    if (enemy.board[y][x] == SHIP_CELL) {
      enemy.board[y][x] = HIT_CELL;
      enemyView[y][x] = HIT_CELL;
      hits++;
      lastHits.add({'x': x, 'y': y});
      print('ПОПАДАНИЕ!');
      if (_isShipSunk(enemy, x, y)) {
        print('КОРАБЛЬ ПОТОПЛЕН!');
        _markAroundSunkShip(enemy, x, y);
      }
      return 'hit'; // Продолжаем ход
    } else {
      enemyView[y][x] = MISS_CELL;
      misses++;
      print('МИМО!');
      return 'miss'; // Ход переходит
    }
  }

  // ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  bool _isShipSunk(Player enemy, int x, int y) {
    final visited = List.generate(BOARD_SIZE, (_) => List.filled(BOARD_SIZE, false));
    final queue = <Map<String, int>>[];
    queue.add({'x': x, 'y': y});
    visited[y][x] = true;
    bool hasAliveParts = false;

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final cx = current['x']!;
      final cy = current['y']!;
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = cx + dx;
          final ny = cy + dy;
          if (nx >= 0 && nx < BOARD_SIZE && ny >= 0 && ny < BOARD_SIZE) {
            if (enemy.board[ny][nx] == SHIP_CELL && !visited[ny][nx]) {
              hasAliveParts = true;
              visited[ny][nx] = true;
              queue.add({'x': nx, 'y': ny});
            }
          }
        }
      }
    }
    return !hasAliveParts;
  }

  void _markAroundSunkShip(Player enemy, int x, int y) {
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        final nx = x + dx;
        final ny = y + dy;
        if (nx >= 0 && nx < BOARD_SIZE && ny >= 0 && ny < BOARD_SIZE) {
          if (enemy.board[ny][nx] != HIT_CELL && enemy.enemyView[ny][nx] == EMPTY_CELL) {
            enemy.enemyView[ny][nx] = MISS_CELL;
          }
        }
      }
    }
  }

  // Умный выбор цели для ИИ (с приоритетом на попадания)
  Map<String, int> _aiChooseTarget(Player enemy) {
    if (lastHits.isNotEmpty) {
      for (final hit in lastHits) {
        final x = hit['x']!;
        final y = hit['y']!;
        final directions = [
          {'dx': 1, 'dy': 0}, {'dx': -1, 'dy': 0},
          {'dx': 0, 'dy': 1}, {'dx': 0, 'dy': -1},
        ];
        directions.shuffle(); // Перемешиваем для случайности
        for (final dir in directions) {
          final nx = x + dir['dx']!;
          final ny = y + dir['dy']!;
          if (nx >= 0 && nx < BOARD_SIZE && ny >= 0 && ny < BOARD_SIZE) {
            if (enemy.enemyView[ny][nx] == EMPTY_CELL) {
              return {'x': nx, 'y': ny}; // Стреляем рядом с попаданием
            }
          }
        }
      }
    }

    // Если попаданий нет, стреляем случайно
    while (true) {
      final x = Random().nextInt(BOARD_SIZE);
      final y = Random().nextInt(BOARD_SIZE);
      if (enemy.enemyView[y][x] == EMPTY_CELL) {
        return {'x': x, 'y': y};
      }
    }
  }

  void _printBoards(Player enemy) {
    print('\nВаше поле ($name):');
    print('   A  B  C  D  E  F  G  H  I  J');
    for (int y = 0; y < BOARD_SIZE; y++) {
      stdout.write('${(y + 1).toString().padLeft(2)} ');
      for (int x = 0; x < BOARD_SIZE; x++) {
        final cell = board[y][x];
        String displayCell;
        if (cell == SHIP_CELL) displayCell = '#';
        else if (cell == HIT_CELL) displayCell = 'X';
        else if (cell == MISS_CELL) displayCell = 'O';
        else displayCell = '~';
        stdout.write('${displayCell.padRight(3)}');
      }
      print('');
    }

    print('\nПоле противника (${enemy.name}):');
    print('   A  B  C  D  E  F  G  H  I  J');
    for (int y = 0; y < BOARD_SIZE; y++) {
      stdout.write('${(y + 1).toString().padLeft(2)} ');
      for (int x = 0; x < BOARD_SIZE; x++) {
        final cell = enemyView[y][x];
        String displayCell;
        if (cell == HIT_CELL) displayCell = 'X';
        else if (cell == MISS_CELL) displayCell = 'O';
        else displayCell = '~';
        stdout.write('${displayCell.padRight(3)}');
      }
      print('');
    }
  }
}

// ОСНОВНОЙ ИГРОВОЙ ЦИКЛ
void playGame(Player player1, Player player2) {
  Player currentPlayer = player1;
  Player enemyPlayer = player2;
  bool gameOver = false;

  while (!gameOver) {
    bool shouldContinue = true;
    while (shouldContinue) {
      final result = currentPlayer.makeMove(enemyPlayer);
      gameOver = _checkWinCondition(enemyPlayer);
      if (gameOver) break;
      shouldContinue = (result == 'hit'); // Продолжаем, если попал (для ИИ тоже)
    }
    if (gameOver) break;

    // Меняем игроков
    final temp = currentPlayer;
    currentPlayer = enemyPlayer;
    enemyPlayer = temp;
  }

  print('\n=== ИГРА ОКОНЧЕНА ===');
  print('${currentPlayer.name} ПОБЕДИЛ!');
  print('Статистика:');
  print('- ${player1.name}: ${player1.hits} попаданий, ${player1.misses} промахов');
  print('- ${player2.name}: ${player2.hits} попаданий, ${player2.misses} промахов');

  stdout.write('\nСыграть ещё раз? (y/n): ');
  final answer = stdin.readLineSync()!.toLowerCase();
  if (answer == 'y') main();
  else print('Спасибо за игру!');
}

// ПРОВЕРКА УСЛОВИЯ ПОБЕДЫ
bool _checkWinCondition(Player player) {
  for (final row in player.board) {
    if (row.contains(SHIP_CELL)) return false;
  }
  return true;
}
