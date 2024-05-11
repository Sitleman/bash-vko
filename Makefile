archive-create:
	tar cfz kr_vko_v$(v).tar.gz ./*

archive-export:
	tar xf kr_vko_v$(v).tar.gz
