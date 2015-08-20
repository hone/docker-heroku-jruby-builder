#!/bin/sh

workspace_dir=$1
output_dir=$2
cache_dir=$3

jruby_src_file=jruby-src-$VERSION.tar.gz

cd $cache_dir
if [ $GIT_URL ]; then
	git clone $GIT_URL release
	cd release
	git checkout $GIT_TREEISH
	MAVEN_OPTS=-XX:MaxPermSize=768m ./mvnw install -Pdist
	cp maven/jruby-dist/target/jruby-dist-$VERSION-src.tar.gz $cache_dir/$jruby_src_file
	cd ..
else
	if [ ! -f $jruby_src_file ]; then
		echo "Downloading $jruby_src_file"
		curl -s -O -L "https://s3.amazonaws.com/jruby.org/downloads/$VERSION/$jruby_src_file"
	fi
fi

cd $workspace_dir
tar zxf $cache_dir/$jruby_src_file
cd jruby-$VERSION
if [ "$VERSION" = "1.7.5" ]; then
	package_file="/tmp/buildpack_*/vendor/package.rb"
	cp $package_file lib/ruby/shared/rubygems
fi

var=$(echo $RUBY_VERSION | awk -F"." '{print $1,$2,$3}')
set -- $var
major=$1
minor=$2
patch=$3

if [ -d mvnw ]; then
  ./mvnw -Djruby.default.ruby.version=$major.$minor -Dmaven.repo.local=$cache_dir/.m2/repository -T4
else
  mvn -Djruby.default.ruby.version=$major.$minor -Dmaven.repo.local=$cache_dir/.m2/repository -T4
fi
rm bin/*.bat
rm bin/*.dll
rm bin/*.exe
rm -rf lib/target
if [ -d lib/jni ] ; then
  find lib/jni/* ! -name x86_64-Linux -print0 | xargs -0 rm -rf --
fi
#ln -s jruby bin/ruby
mkdir -p $output_dir
tar cvzf $output_dir/ruby-$RUBY_VERSION-jruby-$VERSION.tgz bin/ lib/
ls $output_dir
