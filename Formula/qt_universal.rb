class QtUniversal < Formula
  desc "Dual-platform static Qt6"
  homepage "https://github.com/flipperdevices/homebrew-flipper"
  url "https://download.qt.io/official_releases/qt/6.3/6.3.1/single/qt-everywhere-src-6.3.1.tar.xz"
  sha256 "51114e789485fdb6b35d112dfd7c7abb38326325ac51221b6341564a1c3cc726"
  license all_of: ["GFDL-1.3-only", "GPL-2.0-only", "GPL-3.0-only", "LGPL-2.1-only", "LGPL-3.0-only"]

  depends_on "cmake"      => [:build, :test]
  depends_on "ninja"      => :build
  depends_on "pkg-config" => :build
  depends_on "six" => :build
  depends_on xcode: :build
  conflicts_with "qt", because: "qt_universal also ships a full Qt6"

  uses_from_macos "bison" => :build
  uses_from_macos "flex"  => :build
  uses_from_macos "gperf" => :build
  uses_from_macos "perl"  => :build

  fails_with gcc: "5"

  # Remove symlink check causing build to bail out and fail.
  # https://gitlab.kitware.com/cmake/cmake/-/issues/23251
  patch do
    url "https://raw.githubusercontent.com/Homebrew/formula-patches/c363f0edf9e90598d54bc3f4f1bacf95abbda282/qt/qt_internal_check_if_path_has_symlinks.patch"
    sha256 "1afd8bf3299949b2717265228ca953d8d9e4201ddb547f43ed84ac0d7da7a135"
    directory "qtbase"
  end

  def relink_plugins
    #for CUR in $(find . -type f -name "*.cmake" -or -name "*.pri" -or -name "*.prl"); do  sed -i '' 's/\/tmp\/qt-20220920-44821-91zlal\/qt-everywhere-src-6.3.1\/qtbase/\/opt\/homebrew\/Cellar\/qt\/6.3.1_4/g' $CUR; done

    configFiles = %x[find . -type f -name "*.cmake" -or -name "*.pri" -or -name "*.prl"]
    buildPath = "#{buildpath}".sub("/private", "") + "/qtbase"
    configFiles.each do |filename|
      system "sed", "s/#{buildPath}/#{prefix}/g", "#{filename}"
    end
  end

  def install
    config_args = %W[
      -release
      -static
      -qt-zlib
      -qt-libjpeg
      -qt-libpng
      -qt-freetype
      -qt-pcre
      -qt-harfbuzz
      -qt-doubleconversion

      -prefix #{HOMEBREW_PREFIX}
      -extprefix #{prefix}

      -archdatadir share/qt
      -datadir share/qt
      -examplesdir share/qt/examples
      -testsdir share/qt/tests

      -skip qtwebengine
      -nomake tests
      -nomake examples
      -no-feature-relocatable
      -no-sql-mysql
      -no-sql-odbc
      -no-sql-psql
      -no-zstd
      -no-glib
      -no-pch
      -no-icu
    ]

    cmake_args = std_cmake_args(install_prefix: HOMEBREW_PREFIX, find_framework: "FIRST") + [
      "-DINSTALL_MKSPECSDIR=share/qt/mkspecs",
      "-DFEATURE_pkg_config=ON",
      "-DINPUT_system_sqlite=no",
      "-DCMAKE_OSX_ARCHITECTURES=x86_64;arm64;"
    ]

    system "./configure", *config_args, "--", *cmake_args
    system "cmake", "--build", ".", "--parallel"
    system "cmake", "--install", "."

    rm bin/"qt-cmake-private-install.cmake"

    realBuildPath = "#{buildpath}".sub("/private", "") + "/qtbase"
    inreplace Dir["#{prefix}/**/*.{pri,cmake,prl}"], "#{realBuildPath}", "#{prefix}", false
    inreplace lib/"cmake/Qt6/qt.toolchain.cmake", "#{Superenv.shims_path}/", ""

    # The pkg-config files installed suggest that headers can be found in the
    # `include` directory. Make this so by creating symlinks from `include` to
    # the Frameworks' Headers folders.
    # Tracking issues:
    # https://bugreports.qt.io/browse/QTBUG-86080
    # https://gitlab.kitware.com/cmake/cmake/-/merge_requests/6363
    lib.glob("*.framework") do |f|
      # Some config scripts will only find Qt in a "Frameworks" folder
      frameworks.install_symlink f
      include.install_symlink f/"Headers" => f.stem
    end

    bin.glob("*.app") do |app|
      libexec.install app
      bin.write_exec_script libexec/app.basename/"Contents/MacOS"/app.stem
    end
  end

  test do
    (testpath/"CMakeLists.txt").write <<~EOS
      cmake_minimum_required(VERSION #{Formula["cmake"].version})

      project(test VERSION 1.0.0 LANGUAGES CXX)

      set(CMAKE_CXX_STANDARD 17)
      set(CMAKE_CXX_STANDARD_REQUIRED ON)

      set(CMAKE_AUTOMOC ON)
      set(CMAKE_AUTORCC ON)
      set(CMAKE_AUTOUIC ON)

      find_package(Qt6 COMPONENTS Core Widgets Sql Concurrent
        3DCore Svg Quick3D Network NetworkAuth REQUIRED)

      add_executable(test
          main.cpp
      )

      target_link_libraries(test PRIVATE Qt6::Core Qt6::Widgets
        Qt6::Sql Qt6::Concurrent Qt6::3DCore Qt6::Svg Qt6::Quick3D
        Qt6::Network Qt6::NetworkAuth
      )
    EOS

    (testpath/"test.pro").write <<~EOS
      QT       += core svg 3dcore network networkauth quick3d \
        sql
      TARGET = test
      CONFIG   += console
      CONFIG   -= app_bundle
      TEMPLATE = app
      SOURCES += main.cpp
    EOS

    (testpath/"main.cpp").write <<~EOS
      #undef QT_NO_DEBUG
      #include <QCoreApplication>
      #include <Qt3DCore>
      #include <QtQuick3D>
      #include <QImageReader>
      #include <QtNetworkAuth>
      #include <QtSql>
      #include <QtSvg>
      #include <QDebug>
      #include <iostream>

      int main(int argc, char *argv[])
      {
        QCoreApplication a(argc, argv);
        QSvgGenerator generator;
        auto *handler = new QOAuthHttpServerReplyHandler();
        delete handler; handler = nullptr;
        auto *root = new Qt3DCore::QEntity();
        delete root; root = nullptr;
        #ifdef __APPLE__
        Q_ASSERT(QSqlDatabase::isDriverAvailable("QSQLITE"));
        #endif
        const auto &list = QImageReader::supportedImageFormats();
        for(const char* fmt:{"bmp", "cur", "gif",
          #ifdef __APPLE__
            "heic", "heif",
          #endif
          "icns", "ico", "jp2", "jpeg", "jpg", "pbm", "pgm", "png",
          "ppm", "svg", "svgz", "tga", "tif", "tiff", "wbmp", "webp",
          "xbm", "xpm"}) {
          Q_ASSERT(list.contains(fmt));
        }
        return 0;
      }
    EOS

    system "cmake", testpath
    system "make"
    system "./test"

    ENV.delete "CPATH" unless MacOS.version <= :mojave
    system bin/"qmake", testpath/"test.pro"
    system "make"
    system "./test"
  end
end
