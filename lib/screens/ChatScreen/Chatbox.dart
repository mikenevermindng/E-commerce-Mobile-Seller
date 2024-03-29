import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:new_gradient_app_bar/new_gradient_app_bar.dart';
import 'package:seller_app/abstracts/colors.dart';
import 'package:seller_app/abstracts/variables.dart';
import 'package:seller_app/screens/ChatScreen/Message/LeftMessage.dart';
import 'package:seller_app/screens/ChatScreen/Message/RightMessage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../constaint.dart';

class ScreenArguments {
  final String topic;
  final String chatBoxId;

  ScreenArguments(this.topic, this.chatBoxId);
}

class ChatBox extends StatefulWidget {
  static final routeName = '/chatbox';

  ChatBox({
    Key key,
    this.topic,
    this.chatboxId
  });

  final String topic;
  final String chatboxId;

  @override
  _ChatBoxState createState() => _ChatBoxState();
}

class _ChatBoxState extends State<ChatBox> {
  IO.Socket socket;
  List<dynamic> messages = <dynamic>[];
  final _messageController = TextEditingController();
  var dio = Dio();
  final _scrollController = ScrollController();
  String topic;
  String chatboxId;
  dynamic personInChatbox;

  SharedPreferences prefs;
  String currentUserId;

  @override
  void initState() {
    try {
      topic = widget.topic;
      chatboxId = widget.chatboxId;
      SharedPreferences.getInstance().then((value) {
        prefs = value;
        currentUserId = prefs.getString('sellerId');
        dio.get('$chat_url/participants/$chatboxId/$currentUserId').then((value) {
          if (value.data['success']) {
            setState(() {
              personInChatbox = value.data['peopleInChatbox'];
            });
          }
        });
        dio.get('$chat_url/message/$chatboxId/0').then((value) {
          if (value.data['success']) {
            setState(() {
              messages.addAll(value.data['messages']);
            });
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
            connectToChatServer();
          }
        });
      });

      super.initState();
    } catch (e) {
      print(e.toString());
    }
  }

  void connectToChatServer() {
    try {
      print('re init');
      setState(() {
        socket = IO.io('$chat_url', <String, dynamic> {
          'transports': ['websocket'],
          'forceNew':true
        });
        socket.onConnect((data) {
          print('connect: ${socket.id}');
            socket.on('message', (message) {
              if (mounted) {
                setState(() {
                  messages.add(message);
                });
              }
          });
        });

        socket.connect();
        socket.emit('join', chatboxId);
        
        socket.on('disconnect', (_) => print('disconnect'));
        print(socket.connected);
      });
    } catch (e) {
      print(e.toString());
    }
  }

  @override
  void onDispose() {
    super.dispose();
    socket.emit('disconnect');
    setState(() {
      socket = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    Timer(
      Duration(seconds: 0),
        () => _scrollController.jumpTo(_scrollController.position.maxScrollExtent)
    );

    print(personInChatbox);
    return Scaffold(
      appBar: NewGradientAppBar(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            personInChatbox != null ? Container(
              width: MediaQuery.of(context).size.width * 0.11,
              height: MediaQuery.of(context).size.width * 0.11,
              margin: EdgeInsets.only(right: space_medium),
              decoration: BoxDecoration(
                  border: Border.all(width: 1.5, color: color_white),
                  borderRadius:
                      BorderRadius.all(Radius.circular(border_radius_huge)),
                  image: DecorationImage(
                      image: personInChatbox['avatar'] != null ? NetworkImage(personInChatbox['avatar'])
                      : NetworkImage(
                          'https://i0.wp.com/lucloi.vn/wp-content/uploads/2020/04/f45.jpg?fit=800%2C403&ssl=1'),
                      fit: BoxFit.cover)),
            ) : Container(),
            personInChatbox != null ? Text(personInChatbox['username'], style: Theme.of(context).textTheme.bodyText1, maxLines: 1,
              overflow: TextOverflow.ellipsis) : Container()
          ],
        ),
        // title: Text(topic != null ? topic : ''),
        gradient: color_gradient_primary,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios),
            onPressed: () {
              Navigator.pop(context);
            }),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: color_gradient_tertiary),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Container(
                padding: EdgeInsets.only(left: space_small, right: space_small),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    if (message['from'] == currentUserId) {
                      return RightMessage(message: message);
                    } else {
                      return LeftMessage(message: message);
                    }
                  },
                ),
              ),
            ),

            //Chat sender here ^^
            Container(
              padding: EdgeInsets.symmetric(
                  vertical: space_medium, horizontal: space_small),
              width: MediaQuery.of(context).size.width,
              height: space_huge * 2 + space_medium,
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                      icon: Icon(Icons.image_rounded),
                      color: color_secondary,
                      iconSize: space_huge,
                      onPressed: () {}),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      cursorColor: color_secondary,
                      cursorHeight: 18,
                      cursorRadius: Radius.circular(border_radius_huge),
                      cursorWidth: space_tiny - 2,
                      style: Theme.of(context)
                          .textTheme
                          .bodyText1
                          .copyWith(fontSize: 16),
                      controller: _messageController,
                      decoration: InputDecoration.collapsed(
                          hintText: "Gửi tin nhắn đến khách hàng..."),
                    ),
                  ),
                  IconButton(
                      icon: Icon(Icons.send_rounded),
                      color: color_secondary,
                      iconSize: space_huge,
                      onPressed: () {
                        if (_messageController.text.length == 0) {
                          print('nothing to send');
                        } else {
                          socket.emit('sendMessage', {
                            'chatbox': chatboxId,
                            'sender': 'Mạnh Nguyễn',
                            'from': currentUserId,
                            'content': _messageController.text,
                            'images': []
                          });
                        }
                        _scrollController
                            .jumpTo(_scrollController.position.maxScrollExtent);
                        _messageController.clear();
                      }),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
