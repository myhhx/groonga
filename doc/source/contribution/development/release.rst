.. -*- rst -*-

.. highlightlang:: none

リリース手順
============

前提条件
--------

リリース手順の前提条件は以下の通りです。

* ビルド環境は Debian GNU/Linux (sid)
* コマンドラインの実行例はzsh

作業ディレクトリ例は以下を使用します。

* GROONGA_DIR=$HOME/work/groonga
* GROONGA_CLONE_DIR=$HOME/work/groonga/groonga.clean
* GROONGA_ORG_PATH=$HOME/work/groonga/groonga.org
* CUTTER_DIR=$HOME/work/cutter
* CUTTER_SOURCE_PATH=$HOME/work/cutter/cutter

ビルド環境の準備
----------------

以下にGroongaのリリース作業を行うために事前にインストール
しておくべきパッケージを示します。

なお、ビルド環境としては Debian GNU/Linux (sid)を前提として説明しているため、その他の環境では適宜読み替えて下さい。::

    % sudo apt-get install -V debootstrap createrepo rpm mercurial python-docutils python-jinja2 ruby-full mingw-w64 g++-mingw-w64 mecab libmecab-dev nsis gnupg2 dh-autoreconf python-sphinx bison

Debian系（.deb）やRed Hat系（.rpm）パッケージのビルドには `Vagrant <https://www.vagrantup.com/>`_ を使用します。apt-getでインストールできるのは古いバージョンなので、Webサイトから最新版をダウンロードしてインストールすることをおすすめします。

Vagrantで使用する仮想化ソフトウェア（VirtualBox、VMwareなど）がない場合、合わせてインストールしてください。なお、VirtualBoxはsources.listにcontribセクションを追加すればapt-getでインストールできます。::

    % cat /etc/apt/sources.list
    deb http://ftp.jp.debian.org/debian/ sid main contrib
    deb-src http://ftp.jp.debian.org/debian/ sid main contrib
    % sudo apt-get update
    % sudo apt-get install virtualbox

また、rubyのrakeパッケージを以下のコマンドによりインストールします。::

    % sudo gem install rake

パッケージ署名用秘密鍵のインポート
----------------------------------

リリース作業ではRPMパッケージに対する署名を行います。
その際、パッケージ署名用の鍵が必要です。

Groongaプロジェクトでは署名用の鍵をリリース担当者の公開鍵で暗号化してリポジトリのpackages/ディレクトリ以下へと登録しています。

リリース担当者はリポジトリに登録された秘密鍵を復号した後に鍵のインポートを以下のコマンドにて行います。::

    % cd packages
    % gpg --decrypt release-key-secret.asc.gpg.(担当者) > (復号した鍵
    ファイル)
    % gpg --import  (復号した鍵ファイル)

鍵のインポートが正常終了すると gpg --list-keys でGroongaの署名用の鍵を確認することができます。::

    pub   1024R/F10399C0 2012-04-24
    uid                  groonga Key (groonga Official Signing Key)
    <packages@groonga.org>
    sub   1024R/BC009774 2012-04-24

鍵をインポートしただけでは使用することができないため、インポートした鍵に対してtrust,signを行う必要があります。

以下のコマンドを実行して署名を行います。(途中の選択肢は省略)::

    % gpg --edit-key packages@groonga.org
    gpg> trust
    gpg> sign
    gpg> save
    gpg> quit

この作業は、新規にリリースを行うことになった担当者やパッケージに署名する鍵に変更があった場合などに行います。

リリース作業用ディレクトリの作成
--------------------------------

Groongaのリリース作業ではリリース専用の環境下(コンパイルフラグ)でビルドする必要があります。

リリース時と開発時でディレクトリを分けずに作業することもできますが、誤ったコンパイルフラグでリリースしてしまう危険があります。

そのため、以降の説明では$GROONGA_DIR以下のディレクトリにリリース用の作業ディレクトリ(groonga.clean)としてソースコードをcloneしたものとして説明します。

リリース用のクリーンな状態でソースコードを取得するために$GROONGA_DIRにて以下のコマンドを実行します。::

    % git clone --recursive git@github.com:groonga/groonga.git groonga.clean

この作業はリリース作業ごとに行います。

変更点のまとめ
--------------

前回リリース時からの変更点を$GROONGA_CLONE_DIR/doc/source/news.txtにまとめます。
ここでまとめた内容についてはリリースアナウンスにも使用します。

前回リリースからの変更履歴を参照するには以下のコマンドを実行します。::

   % git log -p --reverse $(git tag | tail -1)..

ログを^commitで検索しながら、以下の基準を目安として変更点を追記していきます。

含めるもの

* ユーザへ影響するような変更
* 互換性がなくなるような変更

含めないもの

* 内部的な変更(変数名の変更やらリファクタリング)


Groongaのウェブサイトの取得
---------------------------

GroongaのウェブサイトのソースはGroonga同様にgithubにリポジトリを置いています。

リリース作業では後述するコマンド(make update-latest-release)にてトップページのバージョンを置き換えることができるようになっています。

Groongaのウェブサイトのソースコードを$GROONGA_ORG_PATHとして取得するためには、$GROONGA_DIRにて以下のコマンドを実行します。::

    % git clone git@github.com:groonga/groonga.org.git

これで、$GROONGA_ORG_PATHにgroonga.orgのソースを取得できます。

cutterのソースコード取得
------------------------

Groongaのリリース作業では、cutterに含まれるスクリプトを使用しています。

そこであらかじめ用意しておいた$HOME/work/cutterディレクトリにてcutterのソースコードを以下のコマンドにて取得します。::

    % git clone git@github.com:clear-code/cutter.git

これで、$CUTTER_SOURCE_PATHディレクトリにcutterのソースを取得できます。

configureスクリプトの生成
-------------------------

Groongaのソースコードをcloneした時点ではconfigureスクリプトが含まれておらず、そのままmakeコマンドにてビルドすることができません。

$GROONGA_CLONE_DIRにてautogen.shを以下のように実行します。::

    % sh autogen.sh

このコマンドの実行により、configureスクリプトが生成されます。

configureスクリプトの実行
-------------------------

Makefileを生成するためにconfigureスクリプトを実行します。

リリース用にビルドするためには以下のオプションを指定してconfigureを実行します。::

    % ./configure \
          --prefix=/tmp/local \
          --with-launchpad-uploader-pgp-key=(Launchpadに登録したkeyID) \
          --with-groonga-org-path=$HOME/work/groonga/groonga.org \
          --enable-document \
          --with-ruby \
          --enable-mruby \
          --with-cutter-source-path=$HOME/work/cutter/cutter

configureオプションである--with-groonga-org-pathにはGroongaのウェブサイトのリポジトリをcloneした場所を指定します。

configureオプションである--with-cutter-source-pathにはcutterのソースをcloneした場所を指定します。

以下のようにGroongaのソースコードをcloneした先からの相対パスを指定することもできます。::

    % ./configure \
          --prefix=/tmp/local \
          --with-launchpad-uploader-pgp-key=(Launchpadに登録したkeyID) \
          --with-groonga-org-path=../groonga.org \
          --enable-document \
          --with-ruby \
          --enable-mruby \
          --with-cutter-source-path=../../cutter/cutter

あらかじめpackagesユーザでpackages.groonga.orgにsshログインできることを確認しておいてください。

ログイン可能であるかの確認は以下のようにコマンドを実行して行います。::

    % ssh packages@packages.groonga.org


make update-latest-releaseの実行
--------------------------------

make update-latest-releaseコマンドでは、OLD_RELEASE_DATEに前回のリリースの日付を、NEW_RELEASE_DATEに次回リリースの日付を指定します。

2.0.2のリリースを行った際は以下のコマンドを実行しました。::
::

   % make update-latest-release OLD_RELEASE=2.0.1 OLD_RELEASE_DATE=2012-03-29 NEW_RELEASE_DATE=2012-04-29

これにより、clone済みのGroongaのWebサイトのトップページのソース(index.html,ja/index.html)やRPMパッケージのspecファイルのバージョン表記などが更新されます。

make update-filesの実行
-----------------------

ロケールメッセージの更新や変更されたファイルのリスト等を更新するために以下のコマンドを実行します。::

    % make update-files

make update-filesを実行すると新規に追加されたファイルなどが各種.amファイルへとリストアップされます。

リリースに必要なファイルですので漏れなくコミットします。

make update-poの実行
--------------------

ドキュメントの最新版と各国語版の内容を同期するために、poファイルの更新を以下のコマンドにて実行します。::

    % make update-po

make update-poを実行すると、doc/locale/ja/LC_MESSAGES以下の各種.poファイルが更新されます。

poファイルの翻訳
----------------

make update-poコマンドの実行により更新した各種.poファイルを翻訳します。

翻訳結果をHTMLで確認するために、以下のコマンドを実行します。::

    % make -C doc/locale/ja html
    % make -C doc/locale/en html

確認が完了したら、翻訳済みpoファイルをコミットします。

リリースタグの設定
------------------

リリース用のタグを打つには以下のコマンドを実行します。::

    % make tag

.. note::
   タグを打った後にconfigureを実行することで、ドキュメント生成時のバージョン番号に反映されます。

リリース用アーカイブファイルの作成
----------------------------------

リリース用のソースアーカイブファイルを作成するために以下のコマンドを$GROONGA_CLONE_DIRにて実行します。::

    % make dist

これにより$GROONGA_CLONE_DIR/groonga-(バージョン).tar.gzが作成されます。

.. note::
   タグを打つ前にmake distを行うとversionが古いままになることがあります。
   するとgroonga --versionで表示されるバージョン表記が更新されないので注意が必要です。
   make distで生成したtar.gzのversionおよびversion.shがタグと一致することを確認するのが望ましいです。

パッケージのビルド
------------------

リリース用のアーカイブファイルができたので、パッケージ化する作業を行います。

パッケージ化作業は以下の3種類を対象に行います。

* Debian系(.deb)
* Red Hat系(.rpm)
* Windows系(.exe,.zip)

パッケージのビルドではいくつかのサブタスクから構成されています。

ビルド用パッケージのダウンロード
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

debパッケージのビルドに必要なパッケージをダウンロードするには以下のコマンドを実行します。::

    % cd packages/apt
    % make download

これにより、lucid以降の関連する.debパッケージやソースアーカイブなどがカレントディレクトリ以下へとダウンロードされます。

rpmパッケージのビルドに必要なパッケージをダウンロードするには以下のコマンドを実行します。::

    % cd packages/yum
    % make download

これにより、GroongaやMySQLのRPM/SRPMパッケージなどがカレントディレクトリ以下へとダウンロードされます。

Windowsパッケージのビルドに必要なパッケージをダウンロードするには以下のコマンドを実行します。::

    % cd packages/windows
    % make download

これにより、Groongaのインストーラやzipアーカイブがカレントディレクトリ以下へとダウンロードされます。

sourceパッケージに必要なものをダウンロードするには以下のコマンドを実行します。::

    % cd packages/source
    % make download

これにより過去にリリースしたソースアーカイブ(.tar.gz)が
packages/source/filesディレクトリ以下へとダウンロードされます。


Debian系パッケージのビルド
--------------------------

Groongaのpackages/aptサブディレクトリに移動して、以下のコマンドを実行します。::

    % cd packages/apt
    % make build PALALLEL=yes

make build PALALLEL=yesコマンドを実行すると、ディストリビューションのリリースとアーキテクチャの組み合わせでビルドを平行して行うことができます。

現在サポートされているのは以下の通りです。

* Debian GNU/Linux

  * wheezy i386/amd64
  * jessie i386/amd64

正常にビルドが終了すると$GROONGA_CLONE_DIR/packages/apt/repositories配下に.debパッケージが生成されます。

make build ではまとめてビルドできないこともあります。
その場合にはディストリビューションごとやアーキテクチャごとなど、個別にビルドすることで問題が発生している箇所を切り分ける必要があります。

生成したパッケージへの署名を行うには以下のコマンドを実行します。::

    % make sign-packages

リリース対象のファイルをリポジトリに反映するには以下のコマンドを実行します。::

    % make update-repository

リポジトリにGnuPGで署名を行うために以下のコマンドを実行します。::

    % make sign-repository


Red Hat系パッケージのビルド
---------------------------

Groongaのpackages/yumサブディレクトリに移動して、以下のコマンドを実行します。::

    % cd packages/yum
    % make build PALALLEL=yes

make build PALALLEL=yesコマンドを実行すると、ディストリビューションのリリースとアーキテクチャの組み合わせでビルドを平行して行うことができます。

現在サポートされているのは以下の通りです。

* centos-5 i386/x86_64
* centos-6 i386/x86_64
* centos-7 i386/x86_64

ビルドが正常終了すると$GROONGA_CLONE_DIR/packages/yum/repositories配下にRPMパッケージが生成されます。

* repositories/yum/centos/5/i386/Packages
* repositories/yum/centos/5/x86_64/Packages
* repositories/yum/centos/6/i386/Packages
* repositories/yum/centos/6/x86_64/Packages
* repositories/yum/centos/7/i386/Packages
* repositories/yum/centos/7/x86_64/Packages

リリース対象のRPMに署名を行うには以下のコマンドを実行します。::

    % make sign-packages

リリース対象のファイルをリポジトリに反映するには以下のコマンドを実行します。::

    % make update-repository


Windows用パッケージのビルド
---------------------------

packages/windowsサブディレクトリに移動して、以下のコマンドを実行します。::

    % cd packages/windows
    % make build
    % make package
    % make installer

make releaseを実行することでbuildからuploadまで一気に実行することができますが、途中で失敗することもあるので順に実行することをおすすめします。

make buildでクロスコンパイルを行います。
正常に終了するとdist-x64/dist-x86ディレクトリ以下にx64/x86バイナリを作成します。

make packageが正常に終了するとzipアーカイブをfilesディレクトリ以下に作成します。

make installerが正常に終了するとWindowsインストーラをfilesディレクトリ以下に作成します。

パッケージの動作確認
--------------------

ビルドしたパッケージに対しリリース前の動作確認を行います。

Debian系もしくはRed Hat系の場合には本番環境へとアップロードする前にローカルのaptないしyumのリポジトリを参照して正常に更新できることを確認します。

ここでは以下のようにrubyを利用してリポジトリをwebサーバ経由で参照できるようにします。::

    % ruby -run -e httpd -- packages/yum/repositories (yumの場合)
    % ruby -run -e httpd -- packages/apt/repositories (aptの場合)

grntestの準備
~~~~~~~~~~~~~

grntestを実行するためにはGroongaのテストデータとgrntestのソースが必要です。

まずGroongaのソースを任意のディレクトリへと展開します。::

    % tar zxvf groonga-(バージョン).tar.gz

次にGroongaのtest/functionディレクトリ以下にgrntestのソースを展開します。
つまりtest/function/grntestという名前でgrntestのソースを配置します。::

    % ls test/function/grntest/
    README.md  binlib  license  test

grntestの実行方法
~~~~~~~~~~~~~~~~~

grntestではGroongaコマンドを明示的に指定することができます。
後述のパッケージごとのgrntestによる動作確認では以下のようにして実行します。::

    % GROONGA=(groongaのパス指定) test/function/run-test.sh

最後にgrntestによる実行結果が以下のようにまとめて表示されます。::

    55 tests, 52 passes, 0 failures, 3 not checked tests.
    94.55% passed.

grntestでエラーが発生しないことを確認します。


Debian系の場合
~~~~~~~~~~~~~~

Debian系の場合の動作確認手順は以下の通りとなります。

* 旧バージョンをchroot環境へとインストールする
* chroot環境の/etc/hostsを書き換えてpackages.groonga.orgがホストを
  参照するように変更する
* ホストでwebサーバを起動してドキュメントルートをビルド環境のもの
  (repositories/apt/packages)に設定する
* アップグレード手順を実行する
* grntestのアーカイブを展開してインストールしたバージョンでテストを実
  行する
* grntestの正常終了を確認する


Red Hat系の場合
~~~~~~~~~~~~~~~

Red Hat系の場合の動作確認手順は以下の通りとなります。

* 旧バージョンをchroot環境へとインストール
* chroot環境の/etc/hostsを書き換えてpackages.groonga.orgがホストを参照するように変更する
* ホストでwebサーバを起動してドキュメントルートをビルド環境のもの(packages/yum/repositories)に設定する
* アップグレード手順を実行する
* grntestのアーカイブを展開してインストールしたバージョンでテストを実行する
* grntestの正常終了を確認する


Windows向けの場合
~~~~~~~~~~~~~~~~~

* 新規インストール/上書きインストールを行う
* grntestのアーカイブを展開してインストールしたバージョンでテストを実行する
* grntestの正常終了を確認する

zipアーカイブも同様にしてgrntestを実行し動作確認を行います。

リリースアナウンスの作成
------------------------

リリースの際にはリリースアナウンスを流して、Groongaを広く通知します。

news.txtに変更点をまとめましたが、それを元にリリースアナウンスを作成します。

リリースアナウンスには以下を含めます。

* インストール方法へのリンク
* リリースのトピック紹介
* リリース変更点へのリンク
* リリース変更点(news.txtの内容)

リリースのトピック紹介では、これからGroongaを使う人へアピールする点や既存のバージョンを利用している人がアップグレードする際に必要な情報を提供します。

非互換な変更が含まれるのであれば、回避方法等の案内を載せることも重要です。

参考までに過去のリリースアナウンスへのリンクを以下に示します。

* [Groonga-talk] [ANN] Groonga 2.0.2

    * http://sourceforge.net/mailarchive/message.php?msg_id=29195195

* [groonga-dev,00794] [ANN] Groonga 2.0.2

    * http://osdn.jp/projects/groonga/lists/archive/dev/2012-April/000794.html


パッケージのアップロード
------------------------

動作確認が完了し、Debian系、Red Hat系、Windows向け、ソースコードそれぞれにおいてパッケージやアーカイブのアップロードを行います。

Debian系のパッケージのアップロードには以下のコマンドを実行します。::

    % cd packages/apt
    % make upload

Red Hat系のパッケージのアップロードには以下のコマンドを実行します。::

    % cd packages/yum
    % make upload

Windows向けのパッケージのアップロードには以下のコマンドを実行します。::

    % cd packages/windows
    % make upload

ソースアーカイブのアップロードには以下のコマンドを実行します。::

    % cd packages/source
    % make upload

アップロードが正常終了すると、リリース対象のリポジトリデータやパッケージ、アーカイブ等がpackages.groonga.orgへと反映されます。

Ubuntu用パッケージのアップロード
--------------------------------

Ubuntu向けのパッケージのアップロードには以下のコマンドを実行します。::

    % cd packages/ubuntu
    % make upload

現在サポートされているのは以下の通りです。

* precise i386/amd64
* trusty i386/amd64
* vivid i386/amd64

アップロードが正常終了すると、launchpad.net上でビルドが実行され、ビルド結果がメールで通知されます。ビルドに成功すると、リリース対象のパッケージがlaunchpad.netのGroongaチームのPPAへと反映されます。公開されているパッケージは以下のURLで確認できます。

  https://launchpad.net/~groonga/+archive/ubuntu/ppa

blogroonga(ブログ)の更新
------------------------

http://groonga.org/blog/ および http://groonga.org/blog/ にて公開されているリリース案内を作成します。

基本的にはリリースアナウンスの内容をそのまま記載します。

cloneしたWebサイトのソースに対して以下のファイルを新規追加します。

* groonga.org/en/_post/(リリース日)-release.md
* groonga.org/ja/_post/(リリース日)-release.md


編集した内容をpushする前に確認したい場合にはJekyllおよびRedCloth（Textileパーサー）、RDiscount（Markdownパーサー）、JavaScript interpreter（therubyracer、Node.jsなど）が必要です。
インストールするには以下のコマンドを実行します。::

    % sudo gem install jekyll RedCloth rdiscount therubyracer

jekyllのインストールを行ったら、以下のコマンドでローカルにwebサーバを起動します。::

    % jekyll serve --watch

あとはブラウザにてhttp://localhost:4000にアクセスして内容に問題がないかを確認します。

.. note::
   記事を非公開の状態でアップロードするには.mdファイルのpublished:をfalseに設定します。::

    ---
    layout: post.en
    title: Groonga 2.0.5 has been released
    published: false
    ---


ドキュメントのアップロード
--------------------------

doc/source以下のドキュメントを更新、翻訳まで完了している状態で、ドキュメントのアップロード作業を行います。

そのためにはまず以下のコマンドを実行します。::

    % make update-document

これによりcloneしておいたgroonga.orgのdoc/locale以下に更新したドキュメントがコピーされます。

生成されているドキュメントに問題のないことを確認できたら、コミット、pushしてgroonga.orgへと反映します。

Homebrewの更新
--------------

OS Xでのパッケージ管理方法として `Homebrew <http://brew.sh/>`_ があります。

Groongaを簡単にインストールできるようにするために、Homebrewへpull requestを送ります。

  https://github.com/mxcl/homebrew

すでにGroongaのFormulaは取り込まれているので、リリースのたびにFormulaの内容を更新する作業を実施します。

Groonga 3.0.6のときは以下のように更新してpull requestを送りました。

  https://github.com/mxcl/homebrew/pull/21456/files

上記URLを参照するとわかるようにソースアーカイブのurlとsha1チェックサムを更新します。

リリースアナウンス
------------------

作成したリリースアナウンスをメーリングリストへと流します。

* groonga-dev groonga-dev@lists.osdn.me
* Groonga-talk groonga-talk@lists.sourceforge.net

Twitterでリリースアナウンスをする
---------------------------------

blogroongaのリリースエントリには「リンクをあなたのフォロワーに共有する」ためのツイートボタンがあるので、そのボタンを使ってリリースアナウンスします。(画面下部に配置されている)

このボタンを経由する場合、ツイート内容に自動的にリリースタイトル(「groonga 2.0.8リリース」など)とblogroongaのリリースエントリのURLが挿入されます。

この作業はblogroongaの英語版、日本語版それぞれで行います。
あらかじめgroongaアカウントでログインしておくとアナウンスを円滑に行うことができます。

Facebookでリリースアナウンスをする
----------------------------------

FacebookにGroongaグループがあります。
https://www.facebook.com/groonga/

Groongaグループのメンバーになると、個人のアカウントではなく、Groongaグループのメンバーとして投稿できます。
ブログエントリなどをもとに、リリースアナウンスを投稿します。

以上でリリース作業は終了です。

リリース後にやること
--------------------

リリースアナウンスを流し終えたら、次期バージョンの開発が始まります。

* Groonga プロジェクトの新規バージョン追加
* Groonga のbase_versionの更新

Groonga プロジェクトの新規バージョン追加
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

`Groonga プロジェクトの設定ページ <http://redmine.groonga.org/projects/groonga/settings>`_ にて新規バージョンを追加します。(例: release-2.0.6)

Groonga バージョン更新
~~~~~~~~~~~~~~~~~~~~~~

$GROONGA_CLONE_DIRにて以下のコマンドを実行します。::

    % make update-version NEW_VERSION=2.0.6

これにより$GROONGA_CLONE_DIR/base_versionが更新されるのでコミットしておきます。

.. note::
   base_versionはtar.gzなどのリリース用のファイル名で使用します。


ビルド時のTIPS
--------------

ビルドを並列化したい
~~~~~~~~~~~~~~~~~~~~

make build PALALLEL=yesを指定するとchroot環境で並列にビルドを
実行できます。


特定の環境向けのみビルドしたい
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Debian系の場合、CODES,ARCHITECTURESオプションを明示的に指定することで、特定のリリース、アーキテクチャのみビルドすることができます。

squeezeのi386のみビルドしたい場合には以下のコマンドを実行します。::

    % make build ARCHITECTURES=i386 CODES=squeeze

buildコマンド以外でも build-package-deb build-repository-debなどのサブタスクでもARCHITECTURES,CODES指定は有効です。

Red Hat系の場合、ARCHITECTURES,DISTRIBUTIONSオプションを明示的に指定することで、特定のリリース、アーキテクチャのみビルドすることができます。

fedoraのi386のみビルドしたい場合には以下のコマンドを実行します。::

    % make build ARCHITECTURES=i386 DISTRIBUTIONS=fedora

buildコマンド以外でも build-in-chroot build-repository-rpmなどのサブタスクでもARCHITECTURES,DISTRIBUTIONSの指定は有効です。

centosの場合、CENTOS_VERSIONSを指定することで特定のバージョンのみビルドすることができます。


パッケージの署名用のパスフレーズを知りたい
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

パッケージの署名に必要な秘密鍵のパスフレーズについては
リリース担当者向けの秘密鍵を復号したテキストの1行目に記載してあります。


バージョンを明示的に指定してドキュメントを生成したい
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

リリース後にドキュメントの一部を差し替えたい場合、特に何も指定しないと生成したHTMLに埋め込まれるバージョンが「v3.0.1-xxxxxドキュメント」となってしまうことがあります。gitでのコミット時ハッシュの一部が使われるためです。

これを回避するには、以下のようにDOCUMENT_VERSIONやDOCUMENT_VERSION_FULLを明示的に指定します。::

    % make update-document DOCUMENT_VERSION=3.0.1 DOCUMENT_VERSION_FULL=3.0.1
