import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dashly_mobile/providers/auth_provider.dart';
import 'package:dashly_mobile/services/auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService mockAuthService;
  late AuthProvider authProvider;

  setUp(() {
    mockAuthService = MockAuthService();
    authProvider = AuthProvider(authService: mockAuthService);
  });

  group('AuthProvider Tests', () {
    test('initial state is correct', () {
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.currentUser, isNull);
      expect(authProvider.errorMessage, isNull);
    });

    test('login success sets currentUser and isAuthenticated', () async {
      // Arrange
      when(() => mockAuthService.login(email: 'test@example.com', password: 'password'))
          .thenAnswer((_) async => {
                'user': {
                  'id': 1,
                  'name': 'Test User',
                  'email': 'test@example.com',
                  'role': 'PARTICIPANT'
                },
                'accessToken': 'dummy_token'
              });

      // Act
      final result = await authProvider.login(email: 'test@example.com', password: 'password');

      // Assert
      expect(result, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.currentUser?.email, 'test@example.com');
      expect(authProvider.errorMessage, isNull);
      expect(authProvider.isLoading, isFalse);
    });

    test('login failure sets errorMessage', () async {
      // Arrange
      when(() => mockAuthService.login(email: 'wrong@example.com', password: 'password'))
          .thenThrow(Exception('Invalid credentials'));

      // Act
      final result = await authProvider.login(email: 'wrong@example.com', password: 'password');

      // Assert
      expect(result, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.currentUser, isNull);
      expect(authProvider.errorMessage, 'Invalid credentials');
      expect(authProvider.isLoading, isFalse);
    });

    test('logout clears user data', () async {
      // Arrange
      when(() => mockAuthService.clearToken()).thenAnswer((_) async {});
      
      // We manually simulate a logged-in state first by successfully logging in
      when(() => mockAuthService.login(email: 'test@example.com', password: 'password'))
          .thenAnswer((_) async => {
                'user': {'id': 1, 'name': 'Test', 'email': 'test@example.com', 'role': 'PARTICIPANT'}
              });
      await authProvider.login(email: 'test@example.com', password: 'password');
      expect(authProvider.isAuthenticated, isTrue);

      // Act
      await authProvider.logout();

      // Assert
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.currentUser, isNull);
      verify(() => mockAuthService.clearToken()).called(1);
    });
  });
}
