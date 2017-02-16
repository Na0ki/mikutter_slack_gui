# -*- coding: utf-8 -*-

Plugin.create(:slack_gui) do


  # 実績設定
  # @see http://mikutter.blogspot.jp/2013/03/blog-post.html
  defachievement(:slack_achieve,
                 description: '設定画面からSlackの認証をしよう',
                 hint: 'mikutterの設定を開いてslackの認証ボタンを押そう！'
  ) do |achievement|
    on_slack_connected { |_| achievement.take! }
  end


  # Activity の設定
  defactivity 'slack_connection', 'Slack接続情報'


  intent :slack_channel, label: 'Slack Channelを開く' do |intent_token|
    channel = intent_token.model
    tab_slug = :"slack_temporary_channel_tab_#{channel.id}"
    if Plugin::GUI::Tab.exist?(tab_slug)
      Plugin::GUI::Tab.instance(tab_slug).active!
    else
      tab(tab_slug, channel.name) do
        temporary_tab
        set_deletable true
        timeline(:"slack_temporary_channel_timeline_#{channel.id}")
        active!
      end
    end

    channel.history.next { |messages|
      timeline(:"slack_temporary_channel_timeline_#{channel.id}") << messages
    }.trap { |e| error e }
  end


  # 接続時
  on_slack_connected do |auth|
    activity :slack_connection, "Slackチーム #{auth['team']} の認証に成功しました！"
  end


  # 接続失敗時
  on_slack_connection_failed do |error|
    activity :slack_connection, "Slackチームの認証に失敗しました！: #{error} "
  end


  def image(display_url)
    connection = HTTPClient.new
    connection.get_content(display_url, 'Authorization' => "Bearer #{UserConfig['slack_token']}")
  end


  # コマンド登録
  # コマンドのslugはpost_to_slack_#{チーム名}_#{チャンネル名}の予定
  command(:post_to_slack,
          name: 'Slackに投稿する',
          condition: lambda { |_| true },
          visible: true,
          role: :postbox
  ) do |opt|
    # TODO: mikutter_slack からチャンネルリストの取得を実装する
    msg = Plugin.create(:gtk).widgetof(opt.widget).widget_post.buffer.text # postboxからメッセージを取得
    next if msg.empty?

    channels = []
    # @team.instance_variable_get('@channels').each { |c| channels.push(c.name) }

    dialog = Gtk::Dialog.new('Slackに投稿',
                             $main_application_window,
                             Gtk::Dialog::DESTROY_WITH_PARENT,
                             [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK],
                             [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL])

    dialog.vbox.add(Gtk::Label.new('チャンネル'))
    channel_list = Gtk::ComboBox.new(true)
    dialog.vbox.add(channel_list)
    channels.each { |c| channel_list.append_text(c) }
    channel_list.append_text('mikutter_slack')
    channel_list.set_active(0)

    dialog.show_all
    result = dialog.run

    if result == Gtk::Dialog::RESPONSE_OK
      # channel_name = channels[channel_list.active]
      channel_name = 'mikutter_slack'
      dialog.destroy

      Plugin.call(:slack_post, channel_name, msg)
      # 投稿成功時はpostboxのメッセージを初期化
      Plugin.create(:gtk).widgetof(opt.widget).widget_post.buffer.text = ''
    else
      dialog.destroy
    end
  end

end
