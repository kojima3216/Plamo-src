prune_symlink() {
  echo "pruning symlink in $1"
  if [ -d $1 ] ; then (
    cd $P
    rm -f /tmp/iNsT-a.$$ ; touch /tmp/iNsT-a.$$
    for i in `find ${1#$P/} -type l` ; do
      target=`readlink $i`
      echo "$i -> $target"
      echo $i$'
'$target >> /tmp/iNsT-a.$$
    done
    COUNT=1
    LINE=`sed -n "${COUNT}p" /tmp/iNsT-a.$$`
    while [ -n "$LINE" ] ; do
      LINKGOESIN=`dirname $LINE`
      LINKNAMEIS=`basename $LINE`
      COUNT=$(($COUNT + 1))
      LINKPOINTSTO=`sed -n "${COUNT}p" /tmp/iNsT-a.$$`
      if [ ! -d install ] ; then mkdir install ; fi
      cat <<- EOF >> install/doinst.sh
	( cd $LINKGOESIN ; rm -rf $LINKNAMEIS )
	( cd $LINKGOESIN ; ln -sf $LINKPOINTSTO $LINKNAMEIS )
	EOF
      rm -rf $LINE ; touch -t `date '+%m%d0900'` install/doinst.sh $LINE
      COUNT=$(($COUNT + 1))
      LINE=`sed -n "${COUNT}p" /tmp/iNsT-a.$$`
    done
    rm -f /tmp/iNsT-a.$$
  ) fi
}

convert_links() {
  for i in {$P,$P/usr}/{sbin,bin} ; do prune_symlink $i ; done
  for i in {$P,$P/usr}/lib ; do prune_symlink $i ; done
  for i in {$P,$P/usr}/lib64 ; do prune_symlink $i ; done
  prune_symlink $infodir
  for i in `seq 9` n ; do prune_symlink $mandir/man$i ; done
}


install2() {
  install -d -v ${2%/*} ; install -v -m 644 $1 $2
}

strip_all() {
  for chk in `find . ` ; do
    chk_elf=`file $chk | grep ELF`
    if [ "$chk_elf.x" != ".x" ]; then
      chk_lib=`echo $chk | grep lib`
      if [ "$chk_lib.x" != ".x" ]; then
        echo "stripping $chk with -g "
        strip -g $chk
      else
        echo "stripping $chk"
        strip $chk
      fi
    fi
  done
}

gzip_dir() {
  echo "compressing in $1"
  if [ -d $1 ] ; then (
    cd $1
    files=`ls -f --indicator-style=none | sed '/^\.\{1,2\}$/d'`
    # files=`ls -a --indicator-style=none | tail -n+3`
    for i in $files ; do
      echo "$i"
      if [ ! -f $i -a ! -h $i -o $i != ${i%.gz} ] ; then continue ; fi
      lnks=`ls -l $i | awk '{print $2}'`
      if [ $lnks -gt 1 ] ; then
        inum=`ls -i $i | awk '{print $1}'`
        for j in `find . -maxdepth 1 -inum $inum` ; do
          if [ ${j#./} == $i ] ; then
            gzip -f $i
          else
            rm -f ${j#./} ; ln $i.gz ${j#./}.gz
          fi
        done
      elif [ -h $i ] ; then
        target=`readlink $i` ; rm -f $i ; ln -s $target.gz $i.gz
      else
        gzip $i
      fi
    done
  ) fi
}

gzip_one() {
  gzip $1
}

verify_sig_auto() {
  j=${url%.*}
  for sig in asc sig{,n} {sha{512,256,1},md5}{,sum} ; do
    if wget --spider $url.$sig ; then
      wget $url.$sig
      break
    fi
    if wget --spider $j.$sig ; then
      case ${url##*.} in
        gz) gunzip -c ${url##*/} > ${j##*/} ;;
        bz2) bunzip2 -c ${url##*/} > ${j##*/} ;;
        xz) unxz -c ${url##*/} > ${j##*/} ;;
      esac
      touch -r ${url##*/} ${j##*/} ; url=$j ; wget $url.$sig ; break
    fi
  done
  if [ -f ${url##*/}.$sig ] ; then
    case $sig in
      asc|sig|sign) gpg2 --verify ${url##*/}.$sig ;;
      sha512|sha256|sha1|md5) ${sig}sum -c ${url##*/}.$sig ;;
      *) $sig -c ${url##*/}.$sig ;;
    esac
    if [ $? -ne 0 ] ; then echo "archive verify failed" ; exit ; fi
  fi
}

# ex:
# set
# digest="md5sum:ca03b7c4ba6733658b7cec4b08572458" (command_for_digest:digest)
# then
# compare $(md5sum ${url##*/}) and digest
check_digest() {
  IFS=":"
  set -- $digest
  sum=$( $1 ${url##*/} | awk '{ print $1 }')
  IFS=$' \t\n'
  if [ $sum != $2 ]; then
    exit 1
  fi
}

verify_specified_sig() {
  # signature or digest file
  sigfile=${verify##*/}
  # suffix of $sigfile
  sig_suffix=${sigfile##*.}
  # verify target file
  verified_file=$(basename $sigfile .${sig_suffix})
  # downloaded file
  source_file=${url##*/}
  # compres type of source
  compress_type=${source_file##*.}

  if [ ! -f $sigfile ]; then
    wget $verify
  fi

  if [ $source_file != $verified_file ]; then
    case $compress_type in
      gz) gunzip -c $source_file > $(basename $source_file .${compress_type}) ;;
      bz2) bunzip -c $source_file > $(basename $source_file .${compress_type}) ;;
      xz) unxz -c $source_file > $(basename $source_file .${compress_type}) ;;
    esac
  fi
  case $sig_suffix in
    asc|sig|sign|dsc) gpg2 --verify ${sigfile} ;;
    sha512|sha256|sha1|md5) ${sig_suffix}sum -c ${sigfile} ;;
    *) ${sig_suffix} -c ${sigfile};;
  esac
  if [ $? -ne 0 ]; then
    echo "archive verify failed"
    exit
  fi
}

download_sources() {
  case ${url##*.} in
  git)
    if [ ! -d $(basename ${url##*/} .git) ] ; then
      git clone $url
    else
      ( cd $(basename ${url##*/} .git) ; git pull origin master )
    fi
    ;;
  *)
    if [ ! -f ${url##*/} ] ; then
      wget $url
    fi
    if [ -n "$digest" ] ; then
      check_digest
    elif [ -n "$verify" ] ; then
      verify_specified_sig
    elif [ $USE_VERIFY_SIG_AUTO ] ; then
      verify_sig_auto
    fi
    ;;
  esac
  case ${url##*/} in
  *.tar*) tar xvf ${url##*/} ;;
  *.zip) unzip ${url##*/} ;;
  *git)
    ( cd $(basename ${url##*/} .git)
      git checkout master
      
      if git branch | grep build > /dev/null; then
	git checkout build
      else
        if [ -n "$commitid" ]; then
          git checkout -b build $commitid
	fi
      fi
    ) ;;
  esac
}

# obsolete
verify_checksum() {
  echo "Verify Checksum..."
  checksum_command=$1
  verify_file=${verify##*/}
  for s in $url ; do
    srcsum=`$checksum_command ${s##*/}`
    verifysum=`grep ${s##*/} $verify_file`
    if [ x"$srcsum" != x"$verifysum" ]; then
      exit 1
    fi
  done
  exit 0
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    read -p "Do you want to package as root? [y/N] " ans
    if [ "x$ans" == "xY" -o "x$ans" == "xy" ] ; then
      cd $W ; /bin/su -c "$0 package" ; exit
    fi
  fi
}

check_icons() {
  if [ -d $P/usr/share/icons ] ; then
    echo "icon files installed. execute check-update-cache icons at install time"
    if [ ! -d $P/install ]; then
      mkdir -p $P/install
    fi
    cat <<"EOF" >> $P/install/initpkg
check-update-cache icons
EOF
  fi
}

check_schemas() {
  if [ -d $P/usr/share/glib-2.0/schemas ]; then
    echo "schema files installed. execute check-update-cache schema at install time"
    if [ ! -d $P/install ]; then
      mkdir -p $P/install
    fi
    cat <<"EOF" >> $P/install/initpkg
check-update-cache schema
EOF
  fi
}

check_mime() {
  if [ -d $P/usr/share/mime ]; then
    echo "mime files installed. execute check-update-cache mime at install time"
    if [ ! -d $P/install ]; then
      mkdir -p $P/install
    fi
    cat <<"EOF" >> $P/install/initpkg
check-update-cache mime
EOF
  fi
}

check_applications(){
  if [ -d $P/usr/share/applications ]; then
    echo "desktop data installed. execute check-update-cache desktop at install time"
    if [ ! -d $P/install ]; then
      mkdir -p $P/install
    fi
    cat <<"EOF" >> $P/install/initpkg
check-update-cache desktop
EOF
  fi
}

# インストール後の各種調整
install_tweak() {
  # バイナリファイルを strip
  cd $P
  if [ -z $NO_STRIP ]; then
      strip_all
  fi

  # dir ファイルの削除
  if [ -d $infodir ]; then
    rm -f $infodir/dir
    for info in $infodir/*
    do
      gzip_one $info
    done
  fi

#  # ja 以外のlocaleファイルを削除
#  for loc_dir in `find $P/usr/share -type d -name locale` ; do
#    pushd $loc_dir
#    for loc in * ; do
#      if [ "$loc" != "ja" ]; then
#        rm -rf $loc
#      fi
#    done
#    popd
#  done

  # /run や /var/run がある場合は削除
  if [ -d $P/run ]; then
    rm -vrf $P/run
  fi
  if [ -d $P/var/run ]; then
    rm -vrf $P/var/run
  fi

  #  man ページを圧縮
  if [ -d $P/usr/share/man ]; then
    for mdir in `find $P/usr/share/man -name man[0-9mno] -type d`; do
      gzip_dir $mdir
    done
  fi

  # doc ファイルのインストールと圧縮
  cd $W
  if [ -n "$DOCS" ]; then
      docfiles=()
      for doc in $DOCS ; do
         if [ -d $S/$doc ] ; then
             for i in `find $S/$doc`; do
                 if [ ! -d $i ]; then
                     docfiles=("${docfiles[@]}" ${i##$S/})
                 fi
             done
         else
             docfiles=("${docfiles[@]}" $doc)
         fi
      done

      for i in "${docfiles[@]}" ; do
         echo "installing $i"
         install2 $S/$i $docdir/$src/$i
         touch -r $S/$i $docdir/$src/$i
         gzip_one $docdir/$src/$i
      done
  else
    echo "No docs"
    mkdir -v -p $docdir/$src
  fi
  install -v $myname $docdir/$src
  gzip_one $docdir/$src/$myname

  # パッチファイルのインストール
  for patch in $patchfiles ; do
    cp $W/$patch $docdir/$src/$patch
    gzip_one $docdir/$src/$patch
  done

  # /usr/share/doc 以下のowner.group設定
  chk_me=`whoami | grep root`
  if [ "$chk_me.x" != ".x" ]; then
    chown -R root.root $P/usr/share/doc
  fi

  # /usr/lib/*.la ファイルの移動（ImageMagick は .la ファイルを使うので例外）
  la_files=$(find $P -name "*.la" ! -path "$P/usr/lib/ImageMagick*")
  if [ "${la_files}.x" != ".x" ]; then
    mkdir -p $P/var/local/la-files
    for i in ${la_files} ; do
      mv -v $i $P/var/local/la-files/`basename $i`
    done
  fi

  # check-update-cache で各キャッシュを更新する必要があるか
  check_icons
  check_schemas
  check_mime
  check_applications

}

#####
# set working directories

W=`pwd`
WD=/tmp
S=$W/$src
B=$WD/build
P=$W/work
C=$W/pivot

infodir=$P/usr/share/info
mandir=$P/usr/share/man
#xmandir=$P/usr/X11R7/share/man
docdir=$P/usr/share/doc
myname=`basename $0`
pkg=$pkgbase-$vers-$arch-$build

if [ $arch = "x86_64" ]; then
  target="-m64"
  libdir="lib"
  suffix=""
else
  target="-m32"
  libdir="lib32"
  suffix=""
fi
