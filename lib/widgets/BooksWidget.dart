import 'dart:convert';

import 'package:book/common/DbHelper.dart';
import 'package:book/common/Screen.dart';
import 'package:book/common/common.dart';
import 'package:book/entity/Book.dart';
import 'package:book/event/event.dart';
import 'package:book/model/ShelfModel.dart';
import 'package:book/route/Routes.dart';
import 'package:book/store/Store.dart';
import 'package:book/widgets/ConfirmDialog.dart';
import 'package:book/widgets/has_update_icon_img.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:keframe/frame_separate_widget.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class BooksWidget extends StatefulWidget {
  final String type;

  BooksWidget(this.type);

  @override
  _BooksWidgetState createState() => _BooksWidgetState();
}

class _BooksWidgetState extends State<BooksWidget> {
  Widget body;
  RefreshController _refreshController;
  ShelfModel _shelfModel;
  bool isShelf;
  final double coverWidth = 76.0;

  final double aspectRatio = 0.65;
  double bookPicWidth = SpUtil.getDouble(Common.book_pic_width, defValue: .0);
  final double coverHeight = 122.58;
  int spacingLen = 20;
  int axisLen = 4;

  @override
  void initState() {
    if (bookPicWidth == .0) {
      SpUtil.putDouble(Common.book_pic_width, Screen.width / 4);
    }
    isShelf = this.widget.type == '';
    _shelfModel = Store.value<ShelfModel>(context);
    _refreshController = RefreshController();
    eventBus.on<UpdateBookProcess>().listen((event) {
      _shelfModel.updReadBookProcess(event);
      DbHelper.instance.updBookProcess(
          event.cur, event.index, 0.0, _shelfModel.shelf.first.Id);
    });
    super.initState();
    var widgetsBinding = WidgetsBinding.instance;
    widgetsBinding.addPostFrameCallback((callback) {
      _shelfModel.context = context;
      if (isShelf) {
        _shelfModel.freshToken();
      }
      if (SpUtil.haveKey('auth') && isShelf)
        _refreshController.requestRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SmartRefresher(
        enablePullDown: true,
        footer: CustomFooter(
          builder: (BuildContext context, LoadStatus mode) {
            if (mode == LoadStatus.idle) {
            } else if (mode == LoadStatus.loading) {
              body = CupertinoActivityIndicator();
            } else if (mode == LoadStatus.failed) {
              body = Text("加载失败！点击重试！");
            } else if (mode == LoadStatus.canLoading) {
              body = Text("松手,加载更多!");
            } else {
              body = Text("到底了!");
            }
            return Center(
              child: body,
            );
          },
        ),
        controller: _refreshController,
        onRefresh: freshShelf,
        child: _shelfModel.cover ? coverModel() : listModel());
  }

  //刷新书架
  freshShelf() async {
    if (SpUtil.haveKey('auth')) {
      try {
        await _shelfModel.refreshShelf();
      } catch (e) {
        _refreshController.refreshCompleted();
      }
    }
    _refreshController.refreshCompleted();
  }

  //书架封面模式
  Widget coverModel() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: 4, //主轴上子控件的间距
        runSpacing: 15, //交叉轴上子控件之间的间距
        children: cover(), //要显示的子控件集合
      ),
    );
  }

  Widget bookAction(Widget widget, int i) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        this.widget.type == "sort"
            ? _shelfModel.changePick(i)
            : await readBook(i);
      },
      child: widget,
      onLongPress: () {
        Routes.navigateTo(
          context,
          Routes.sortShelf,
        );
      },
    );
  }

  /**
   * 封面子项
   */
  List<Widget> cover() {
    List<Widget> wds = [];
    List<Book> books = _shelfModel.shelf;
    Book book;
    for (int i = 0; i < books.length; i++) {
      book = books[i];
      wds.add(Container(
        width: coverWidth,
        child: bookAction(
            Column(
              children: [
                HasUpdateIconImg(coverWidth, coverHeight, this.widget.type, i),
                SizedBox(
                  height: 5,
                ),
                Center(
                  child: Text(
                    book.Name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              ],
            ),
            i),
      ));
    }
    int len = 0;

    len = (Screen.width - 20) ~/ coverWidth;
    if (((Screen.width - 20) % coverWidth) < (len - 1) * 5) {
      len -= 1;
    }
    SpUtil.putInt("lenx", len);
    // }
    //不满4的倍数填充container
    int z = wds.length < len ? len - wds.length : len - wds.length % len;
    if (z != 0) {
      for (var i = 0; i < z; i++) {
        wds.add(Container(
          width: coverWidth,
        ));
      }
    }
    return wds;
  }

  //书架列表模式
  Widget listModel() {
    return ListView.builder(
      cacheExtent: 500,
      itemCount: _shelfModel.shelf.length,
      itemBuilder: (c, i) => FrameSeparateWidget(
        index: i,
        child: bookAction(getBookItemView(i), i),
      ),
    );
  }

  Future readBook(int i) async {
    var b = _shelfModel.shelf[i];
    Routes.navigateTo(
      context,
      Routes.read,
      params: {
        'read': jsonEncode(b),
      },
    );
    _shelfModel.sort(i);
  }

  /**
   * 列表子项
   */
  getBookItemView(int i) {
    Book item = _shelfModel.shelf[i];
    return Dismissible(
      key: Key(item.Id.toString()),
      child: Container(
        height: bookPicWidth / aspectRatio,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: <Widget>[
            HasUpdateIconImg(
                bookPicWidth, bookPicWidth / aspectRatio, this.widget.type, i),
            //expanded 回占据剩余空间 text maxLine=1 就不会超过屏幕了
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.Name,
                      style: TextStyle(
                          fontSize: 18.0, fontWeight: FontWeight.bold),
                      maxLines: 1,
                    ),
                    Text(
                      item.Author,
                      style: TextStyle(
                        fontSize: 12.0,
                      ),
                      maxLines: 1,
                    ),
                    Text(
                      item.LastChapter,
                      style: TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      item?.UTime ?? '',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      onDismissed: (direction) {
        _shelfModel.modifyShelf(item);
      },
      background: Container(
        color: Colors.green,
        // 这里使用 ListTile 因为可以快速设置左右两端的Icon
        child: ListTile(
          leading: Icon(
            Icons.bookmark,
            color: Colors.white,
          ),
        ),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        // 这里使用 ListTile 因为可以快速设置左右两端的Icon
        child: ListTile(
          trailing: Icon(
            Icons.delete,
            color: Colors.white,
          ),
        ),
      ),
      confirmDismiss: (direction) async {
        var _confirmContent;

        var _alertDialog;

        if (direction == DismissDirection.endToStart) {
          // 从右向左  也就是删除
          _confirmContent = '确认删除     ${item.Name}';
          _alertDialog = ConfirmDialog(
            _confirmContent,
            () {
              // 展示 SnackBar
              Navigator.of(context).pop(true);
            },
            () {
              Navigator.of(context).pop(false);
            },
          );
        } else {
          return false;
        }
        var isDismiss = await showDialog(
            context: context,
            builder: (context) {
              return _alertDialog;
            });
        return isDismiss;
      },
    );
  }

  @override
  void dispose() {
    _refreshController?.dispose();
    super.dispose();
  }
}
