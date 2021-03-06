import 'package:book/entity/Book.dart';
import 'package:event_bus/event_bus.dart';

EventBus eventBus = new EventBus();

class AddEvent {}

class RollEvent {
  String roll;
  RollEvent(this.roll);
}

class OpenEvent {
  String name;

  OpenEvent(this.name);
}
class ZEvent {
  bool isPage;
  double offset;

  ZEvent(this.isPage,this.offset);
}
class PlayEvent {
  String name;

  PlayEvent(this.name);
}

class OpenChapters {
  String name;

  OpenChapters(this.name);
}

class NavEvent {
  int idx;

  NavEvent(this.idx);
}

class PageEvent {
  int page;

  PageEvent(this.page);
}

class SyncShelfEvent {
  String msg;

  SyncShelfEvent(this.msg);
}

class ChapterEvent {
  int chapterId;

  ChapterEvent(this.chapterId);
}

class BooksEvent {
  List<Book> books;

  BooksEvent(this.books);
}

class ReadRefresh {
  var em;

  ReadRefresh(this.em);
}
