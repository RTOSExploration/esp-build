#!/usr/bin/env bash
# Build wllvm for esp-idf example projects
# Download https://github.com/espressif/llvm-project/releases

compile() {
  #PROJECT_DIR=$IDF_PATH/examples/get-started/hello_world
  PROJECT_DIR=$1
  SUB_DIR=${PROJECT_DIR#$APP_ROOT_DIR}
  BUILD_DIR=build/$SUB_DIR
  DB=$RTOSExploration/bitcode-db/esp-idf-examples/$SUB_DIR
  #[ -d "$DB" ] && echo "Directory $DB exists" && return 0
  [ -f "$DB/DONE" ] && echo "Database $DB already built" && return 0
  rm -rf $DB $BUILD_DIR

  DEF=$PROJECT_DIR/sdkconfig.defaults
  CONF_OPTION='CONFIG_PARTITION_TABLE_OFFSET=0x9000'
  # if sdkconfig.defaults does not exist or does not contain the config option
  if [ ! -f $DEF ] || [ -z "$(grep $CONF_OPTION $DEF)" ]; then
    echo $CONF_OPTION >> $DEF
  fi

  idf.py -C $PROJECT_DIR -B $BUILD_DIR set-target esp32
  idf.py -C $PROJECT_DIR -B $BUILD_DIR build

  mkdir -p $DB
  for elf in $(find $BUILD_DIR \( -name "*.out" -o -name "*.elf" \) ! -name "a.out" -executable); do
    echo ELF file $elf
    # llvm-link and llvm-dis in in /usr/lib/llvm-14, not espressif's llvm
    extract-bc $elf -l llvm-link-14 && llvm-dis-14 $elf.bc && \
      cp --backup=numbered $elf.bc $elf.ll $DB
  done

  touch $DB/DONE
  rm -rf $BUILD_DIR # save disk space
}


. $IDF_PATH/export.sh
export PATH=$(realpath ../xtensa-esp32-elf-clang/bin):$PATH
export IDF_TOOLCHAIN=clang
export WLLVM_OUTPUT_LEVEL=INFO
export LLVM_COMPILER=clang
export BINUTILS_TARGET_PREFIX=xtensa-esp32-elf
#LLVM_COMPILER_PATH=/usr/lib/llvm-14/bin

APP_ROOT_DIR=$IDF_PATH/examples
APP_DIRS=$(find $APP_ROOT_DIR -type d -exec test -f '{}'/CMakeLists.txt \; -print -prune)
#echo $APP_DIRS
for SRC_DIR in $APP_DIRS; do
  compile $SRC_DIR
done
