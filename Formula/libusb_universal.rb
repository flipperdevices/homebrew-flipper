class LibusbUniversal < Formula
  desc "Dual-platform library for USB device access"
  homepage "https://libusb.info/"
  url "https://github.com/libusb/libusb/releases/download/v1.0.24/libusb-1.0.24.tar.bz2"
  sha256 "7efd2685f7b327326dcfb85cee426d9b871fd70e22caa15bb68d595ce2a2b12a"
  license "LGPL-2.1-or-later"

  depends_on "autoconf" => :build
  depends_on "automake" => :build

  def build_arch(arch)
    rm "Makefile", force: true
    system "arch", "-#{arch}", "./configure", "CFLAGS=-mmacosx-version-min=10.14", "--prefix=#{prefix}/#{arch}"
    system "arch", "-#{arch}", "make", "clean"
    system "arch", "-#{arch}", "make"
    system "arch", "-#{arch}", "make", "install"
  end

  def join
    mkdir_p "#{lib}/pkgconfig"
    system "lipo", "-create", "-output", "#{lib}/libusb-1.0.0.dylib",
           "#{prefix}/x86_64/lib/libusb-1.0.0.dylib", "#{prefix}/arm64/lib/libusb-1.0.0.dylib"
    system "lipo", "-create", "-output", "#{lib}/libusb-1.0.a",
           "#{prefix}/x86_64/lib/libusb-1.0.a", "#{prefix}/arm64/lib/libusb-1.0.a"
    ln_s "libusb-1.0.0.dylib", "#{lib}/libusb-1.0.dylib"
    mv "#{prefix}/x86_64/include", "#{prefix}/"
  end

  def clear
    rm_r "#{prefix}/x86_64", force: true
    rm_r "#{prefix}/arm64", force: true
  end

  def install
    build_arch("x86_64")
    build_arch("arm64")
    join
    clear
  end

  test do
    system "true"
  end
end