import 'package:book/common/DbHelper.dart';
import 'package:book/common/Http.dart';
import 'package:book/common/common.dart';
import 'package:book/entity/Book.dart';
import 'package:book/event/event.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:dio/dio.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/cupertino.dart';

class ShelfModel with ChangeNotifier {
  List<Book> shelf = [];

  bool inShelf(var id) {
    return shelf.map((f) => f.Id).toList().contains(id);
  }

  ShelfModel() {
    setShelf();
  }
  updReadBookProcess(UpdateBookProcess up) {
    var b = shelf.first;
    b.cur = up.cur;
    b.index = up.index;
    notifyListeners();
  }

  Future<void> setShelf() async {
    if (_dbHelper == null) {
      _dbHelper = DbHelper();
    }
    shelf = await _dbHelper.getBooks();
    notifyListeners();
  }

  BuildContext context;
  bool cover = SpUtil.getBool("cover", defValue: true);
  bool sortShelf = false;
  DbHelper _dbHelper = DbHelper.instance;
  List<bool> _picks = [];

  bool pickAllFlag = false;

  initPicks() {
    pickAllFlag = false;
    _picks = [];
    for (var i = 0; i < shelf.length; i++) {
      _picks.add(false);
    }
  }

  removePicks() async {
    List<Book> bks = [];
    List<String> ids = [];
    List<bool> pics = [];

    for (var i = 0; i < _picks.length; i++) {
      if (_picks[i]) {
        await delLocalCache([shelf[i].Id]);
        ids.add(shelf[i].Id);
      } else {
        bks.add(shelf[i]);
        pics.add(_picks[i]);
      }
    }
    shelf = bks;
    _picks = pics;
    sortShelf = false;
    deleteCloudIds(ids);
    notifyListeners();
  }

  deleteCloudIds(List<String> ids) async {
    if (SpUtil.haveKey("auth")) {
      for (var id in ids) {
        await HttpUtil().http().get(Common.bookAction + '/$id/del');
      }
    }
    BotToast.showText(text: "删除书籍成功");
  }

  pickAll() {
    _picks = [];
    for (var i = 0; i < shelf.length; i++) {
      _picks.add(!pickAllFlag);
    }
    pickAllFlag = !pickAllFlag;

    notifyListeners();
  }

  bool picks(int i) {
    if (_picks.isEmpty) {
      for (var i = 0; i < shelf.length; i++) {
        _picks.add(false);
      }
    }
    if (_picks.length < shelf.length) {
      for (var i = 0; i < shelf.length - _picks.length; i++) {
        _picks.add(false);
      }
    }
    return _picks[i];
  }

  changePick(int i) {
    _picks[i] = !_picks[i];
    notifyListeners();
  }

  bool hasPick() {
    return _picks.contains(true);
  }

  toggleModel() {
    cover = !cover;
    SpUtil.putBool("cover", cover);
    notifyListeners();
  }

  sortShelfModel() {
    initPicks();
    sortShelf = !sortShelf;
    notifyListeners();
  }

  refreshShelf() async {
    Response response2 = await HttpUtil().http().get(Common.shelf);
    List decode = response2.data['data'];
    if (decode == null) {
      return;
    }
    List<Book> bs = decode.map((m) => Book.fromJson(m)).toList();
    if (shelf.isNotEmpty) {
      var ids = shelf.map((f) => f.Id).toList();
      bs.forEach((f) {
        if (!ids.contains(f.Id)) {
          _dbHelper.addBooks([f]);
          f.sortTime = DateUtil.getNowDateMs();
          shelf.add(f);
        }
      });
      for (var i = 0; i < shelf.length; i++) {
        for (var j = 0; j < bs.length; j++) {
          if (shelf[i].Id == bs[j].Id) {
            if (shelf[i].LastChapter != bs[j].LastChapter) {
              shelf[i].UTime = bs[j].UTime;
              shelf[i].LastChapter = bs[j].LastChapter;
              shelf[i].NewChapterCount = 1;
              shelf[i].Img = bs[j].Img;
              _dbHelper.updBook(
                  bs[j].LastChapter, 1, bs[j].UTime, bs[j].Img, shelf[i].Id);
            }
          }
        }
      }
    } else {
      bs.forEach((element) {
        element.sortTime = DateUtil.getNowDateMs();
        shelf.add(element);
      });
      _dbHelper.addBooks(bs);
    }
    notifyListeners();
  }

  sort(int i) async {
    var book = shelf[i];
    book.NewChapterCount = 0;
    book.sortTime = DateUtil.getNowDateMs();

    shelf.sort((o1, o2) => o2.sortTime.compareTo(o1.sortTime));
    notifyListeners();
    await _dbHelper.sortBook(book.Id);
  }

  dropAccountOut() async {
    SpUtil.clear();
    await delLocalCache(shelf.map((f) => f.Id.toString()).toList());
    shelf = [];
    notifyListeners();
  }

//根据id判断书架是否存在本书
  bool exitsInBookShelfById(String id) {
    return shelf.map((f) => f.Id).toList().contains(id);
  }

  //删除本地记录
  Future<void> delLocalCache(List<String> ids) async {
    for (var i = 0; i < ids.length; i++) {
      await _dbHelper.delBookAndCps(ids[i]);
    }
  }

  modifyShelf(Book book) async {
    var action =
        shelf.map((f) => f.Id).toList().contains(book.Id) ? 'del' : 'add';
    if (action == "add") {
      shelf.insert(0, book);
      _dbHelper.addBooks([book]);
      BotToast.showText(text: "已添加到书架");
    } else if (action == "del") {
      for (var i = 0; i < shelf.length; i++) {
        if (shelf[i].Id == book.Id) {
          shelf.removeAt(i);
        }
      }
      _dbHelper.delBook(book.Id);

      await delLocalCache([book.Id]);
      BotToast.showText(text: "已移除出书架");
    }
    if (SpUtil.haveKey("auth")) {
      HttpUtil().http().get(Common.bookAction + '/${book.Id}/$action');
    }
    notifyListeners();
  }

  freshToken() async {
    if (SpUtil.haveKey("username")) {
      Response res = await HttpUtil().http().get(Common.freshToken);
      var data = res.data;
      if (data['code'] == 200) {
        SpUtil.putString("auth", data['data']['token']);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
