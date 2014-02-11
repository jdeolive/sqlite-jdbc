# use JDK1.5 to build native libraries

include Makefile.common

RESOURCE_DIR = src/main/resources

.phony: all package win mac linux native deploy

all: package

deploy: 
	mvn deploy 

WORK:=target
WORK_DIR=$(WORK)/dll/$(sqlite)/native
UPDATE_FLAG=$(WORK)/dll/$(sqlite)/UPDATE
BUILD:=$(WORK)/build
NATIVE_DLL:=$(WORK_DIR)/$(LIB_FOLDER)/$(LIBNAME)

SQLITE_DLL=$(BUILD)/$(target)/$(LIBNAME)
SQLITE_BUILD_DIR=$(BUILD)/$(sqlite)-$(target)


$(UPDATE_FLAG): $(SQLITE_DLL)
	mkdir -p $(WORK_DIR)/$(LIB_FOLDER)
	cp $(SQLITE_DLL) $(WORK_DIR)/$(LIB_FOLDER) 
	mkdir -p $(RESOURCE_DIR)/native/$(LIB_FOLDER)
	cp $(NATIVE_DLL) $(RESOURCE_DIR)/native/$(LIB_FOLDER)
	touch $(UPDATE_FLAG)

native: $(UPDATE_FLAG)

package: $(UPDATE_FLAG)
	rm -rf target/dependency-maven-plugin-markers
ifeq ($(OS_NAME),Mac)
	DYLD_LIBRARY_PATH=$(SPATIAL_LIB_PATH) \
else
endif
	mvn -Djava.library.path="$(SPATIAL_LIB_PATH)" -P spatialite package

clean-native:
	rm -rf $(SQLITE_BUILD_DIR) $(UPDATE_FLAG)



purejava: $(BUILD)/org/sqlite/SQLite.class
	mkdir -p $(RESOURCE_DIR)/org/sqlite
	cp $< $(RESOURCE_DIR)/org/sqlite/SQLite.class

$(BUILD)/org/sqlite/SQLite.class: 
	make -f Makefile.purejava

test-purejava:
	mvn -DargLine="-Dsqlite.purejava=true" test	

test:
	mvn test

clean:
	rm -rf $(WORK)



$(SQLITE_DLL): $(SQLITE_BUILD_DIR)/sqlite3.o $(BUILD)/org/spatialite/NativeDB.class src/main/java/org/spatialite/NativeDB.c
	@mkdir -p $(dir $@)
	$(JAVAH) -classpath $(BUILD) -jni \
		-o $(BUILD)/NativeDB.h org.spatialite.NativeDB
	$(CC) $(CFLAGS) -c -o $(BUILD)/$(target)/NativeDB.o \
		src/main/java/org/spatialite/NativeDB.c
	$(CC) $(CFLAGS) $(LINKFLAGS) -o $@ \
		$(BUILD)/$(target)/NativeDB.o $(SQLITE_BUILD_DIR)/*.o \
		$(POST_LINKFLAGS)
	$(STRIP) $@

$(BUILD)/$(sqlite)-%/sqlite3.o: $(WORK)/dl/$(sqlite)-amal.zip $(WORK)/dl/$(spatialite)-amal.zip
	@mkdir -p $(dir $@)
	$(info building a native library for os:$(OS_NAME) arch:$(OS_ARCH))
	unzip -qo $(WORK)/dl/$(sqlite)-amal.zip -d $(BUILD)/$(sqlite)-$*
	unzip -qo $(WORK)/dl/$(spatialite)-amal.zip -d $(BUILD)
	cp $(BUILD)/libspatialite-*/spatialite.c src/main/ext
ifeq ($(OS_NAME),Windows)
	sed -i 's/sqlite3_api;/sqlite3_api = 0;/g' $(BUILD)/$(sqlite)-$*/sqlite3ext.h
else
	perl -pi -e "s/sqlite3_api;/sqlite3_api = 0;/g" \
	    $(BUILD)/$(sqlite)-$*/sqlite3ext.h
endif
# insert a code for loading extension functions
ifeq ($(OS_NAME),Windows)
	sed -i 's/^opendb_out:/  if(\!db->mallocFailed \&\& rc==SQLITE_OK){ rc = RegisterExtensionFunctions(db); }\nopendb_out:/g' $(BUILD)/$(sqlite)-$*/sqlite3.c
else
	perl -pi -e "s/^opendb_out:/  if(!db->mallocFailed && rc==SQLITE_OK){ rc = RegisterExtensionFunctions(db); }\nopendb_out:/;" \
	    $(BUILD)/$(sqlite)-$*/sqlite3.c
endif
	cat src/main/ext/*.c >> $(BUILD)/$(sqlite)-$*/sqlite3.c
	(cd $(BUILD)/$(sqlite)-$*; $(CC) -o sqlite3.o -c $(CFLAGS) \
	    -DSQLITE_ENABLE_LOAD_EXTENSION=1 \
	    -DSQLITE_ENABLE_UPDATE_DELETE_LIMIT \
	    -DSQLITE_ENABLE_COLUMN_METADATA \
	    -DSQLITE_CORE \
	    -DSQLITE_ENABLE_FTS3 \
	    -DSQLITE_ENABLE_FTS3_PARENTHESIS \
	    -DSQLITE_ENABLE_RTREE \
	    -DSQLITE_ENABLE_STAT2 \
	    $(SQLITE_FLAGS) \
	    sqlite3.c)

$(BUILD)/org/spatialite/%.class: src/main/java/org/spatialite/%.java
	@mkdir -p $(BUILD)
	$(JAVAC) -source 1.5 -target 1.5 -sourcepath src/main/java -d $(BUILD) $<

$(WORK)/dl/$(sqlite)-amal.zip:
	@mkdir -p $(dir $@)
	curl -o$@ \
	http://www.sqlite.org/sqlite-amalgamation-$(subst .,_,$(version)).zip

$(WORK)/dl/$(spatialite)-amal.zip:
	@mkdir -p $(dir $@)
	curl -o$@ \
	http://www.gaia-gis.it/gaia-sins/libspatialite-sources/libspatialite-amalgamation-$(spatialite_version).zip


