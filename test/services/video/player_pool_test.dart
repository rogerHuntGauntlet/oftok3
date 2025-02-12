import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:ohftokv3/services/video/player_pool.dart';
import 'package:ohftokv3/services/video/media_kit_player_service.dart';

@GenerateNiceMocks([MockSpec<MediaKitPlayerService>()])
import 'player_pool_test.mocks.dart';

void main() {
  late PlayerPool playerPool;
  late MockMediaKitPlayerService mockPlayer;
  late int mockPlayerCount;

  setUp(() {
    mockPlayer = MockMediaKitPlayerService();
    mockPlayerCount = 0;
    
    when(mockPlayer.initialize(any)).thenAnswer((_) => Future.value());
    when(mockPlayer.pause()).thenAnswer((_) => Future.value());
    when(mockPlayer.dispose()).thenAnswer((_) => Future.value());

    playerPool = PlayerPool(
      maxPlayers: 2,
      createPlayer: () {
        mockPlayerCount++;
        return mockPlayer;
      },
    );
  });

  group('PlayerPool', () {
    test('should create pool with correct max players', () {
      expect(playerPool.maxPlayers, equals(2));
      expect(playerPool.activePlayerCount, equals(0));
      expect(playerPool.availablePlayerCount, equals(0));
    });

    test('should throw assertion error if maxPlayers <= 0', () {
      expect(() => PlayerPool(maxPlayers: 0), throwsAssertionError);
      expect(() => PlayerPool(maxPlayers: -1), throwsAssertionError);
    });

    test('should checkout new player when pool is empty', () async {
      final player = await playerPool.checkoutPlayer('video1.mp4');
      expect(player, equals(mockPlayer));
      expect(playerPool.activePlayerCount, equals(1));
      expect(playerPool.availablePlayerCount, equals(0));
      verify(mockPlayer.initialize('video1.mp4')).called(1);
    });

    test('should reuse existing player for same URL', () async {
      final player1 = await playerPool.checkoutPlayer('video1.mp4');
      final player2 = await playerPool.checkoutPlayer('video1.mp4');
      expect(player1, equals(player2));
      expect(playerPool.activePlayerCount, equals(1));
      verify(mockPlayer.initialize('video1.mp4')).called(1);
    });

    test('should recycle least recently used player when max players reached', () async {
      await playerPool.checkoutPlayer('video1.mp4');
      await playerPool.checkoutPlayer('video2.mp4');
      final player3 = await playerPool.checkoutPlayer('video3.mp4');
      
      expect(playerPool.activePlayerCount, equals(2));
      expect(player3, equals(mockPlayer));
      verify(mockPlayer.initialize('video1.mp4')).called(1);
      verify(mockPlayer.initialize('video2.mp4')).called(1);
      verify(mockPlayer.initialize('video3.mp4')).called(1);
    });

    test('should return player to available pool', () async {
      await playerPool.checkoutPlayer('video1.mp4');
      await playerPool.returnPlayer('video1.mp4');
      
      expect(playerPool.activePlayerCount, equals(0));
      expect(playerPool.availablePlayerCount, equals(1));
      verify(mockPlayer.pause()).called(1);
    });

    test('should dispose all players', () async {
      await playerPool.checkoutPlayer('video1.mp4');
      await playerPool.checkoutPlayer('video2.mp4');
      await playerPool.dispose();
      
      expect(playerPool.activePlayerCount, equals(0));
      expect(playerPool.availablePlayerCount, equals(0));
      verify(mockPlayer.dispose()).called(mockPlayerCount);
      
      expect(() => playerPool.checkoutPlayer('video3.mp4'), 
        throwsA(isA<StateError>()));
    });
  });
} 