get:
	tar xf buildroot-2013.05.tar.xz
	mv buildroot-2013.05 src

init:
	cp buildroot-2013.05-spondoolies.bbb src/.config
	@rm -rf tools/customize-rootfs.sh tools/lzma-compress.sh
	touch tools/customize-rootfs.sh
	touch tools/lzma-compress.sh
	chmod +x tools/*
	make -C src

build:
deploy:
	@rm -rf tools/customize-rootfs.sh tools/lzma-compress.sh
	ln -s customize-rootfs-real.sh tools/customize-rootfs.sh
	ln -s lzma-compress-real.sh tools/lzma-compress.sh
	@rm -rf src/output/images/*
	make -C src
