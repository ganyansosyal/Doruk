import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Eski web uygulamasındaki doruk-sohbet projesi ayarları
const _options = FirebaseOptions(
  apiKey: 'AIzaSyCZk-OgjuuO8t4SNary0L2C8WyhyC8IWMA',
  appId: '1:155992007314:web:3d7f16edd31774f60f3c4b',
  messagingSenderId: '155992007314',
  projectId: 'doruk-sohbet',
  authDomain: 'doruk-sohbet.firebaseapp.com',
  databaseURL: 'https://doruk-sohbet-default-rtdb.firebaseio.com',
  storageBucket: 'doruk-sohbet.firebasestorage.app',
);

bool firebaseReady = false;

/// Hata verirse uygulama yine de açılır (Firebase'siz sayfalar çalışır).
Future<void> initFirebase() async {
  try {
    await Firebase.initializeApp(options: _options);
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false;
  }
}

/// Tek yerden veritabanı erişimi: db().ref('mesajlar') gibi
FirebaseDatabase db() => FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://doruk-sohbet-default-rtdb.firebaseio.com',
    );
