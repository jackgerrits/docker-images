# tl;dr
# (docker needs to be configured with 16+ cores and 32GB ram or change the -j16)
# * docker build - < centos7_6_1860-build.Dockerfile
# (replace 27c82a691b62 with whatever got printed at the end of docker build)
# * docker tag 27c82a691b62 eisber/centos7.6.1810-build:0.1.0
# * docker push eisber/centos7.6.1810-build

FROM centos:centos7.6.1810

RUN yum -y updateinfo \
   && yum install -y \
   # C++ to bootstrap
   gcc-c++ gcc git make wget \
   # Java
   maven \
   # Dependencies
   boost-static glibc-static \
   # gcc-9.2 pre-requisites
   bzip2 bison yacc flex \
   # Java
   java-11-openjdk

# Install CMake 3.13
RUN version=3.13 && build=5 \
   && mkdir ~/temp-cmake \
   && cd ~/temp-cmake \
   && wget https://cmake.org/files/v$version/cmake-$version.$build-Linux-x86_64.sh \
   && mkdir /opt/cmake \
   && sh cmake-$version.$build-Linux-x86_64.sh --prefix=/opt/cmake --skip-license \
   && for filename in /opt/cmake/bin/*; do echo Registering $filename; ln -fs $filename /usr/local/bin/`basename $filename`; done \
   && rm -f cmake-$version.$build-Linux-x86_64.sh

# Install gcc-9.2
RUN wget ftp://ftp.mirrorservice.org/sites/sourceware.org/pub/gcc/releases/gcc-9.2.0/gcc-9.2.0.tar.gz \
   && tar xfz gcc-9.2.0.tar.gz \
   && cd gcc-9.2.0 \
   && ./contrib/download_prerequisites \
   && ./configure --disable-multilib --enable-languages=c,c++ --with-pic \
   && make -j$(nproc) \
   && make install \
   && cd .. && rm -rf gcc-9.2.0.tar.gz gcc-9.2.0 \
   && chmod +x /usr/local/libexec/gcc/x86_64-pc-linux-gnu/9.2.0/cc1plus

# Install FlatBuffers 1.12.0
RUN version=1.12.0 && \
   wget https://github.com/google/flatbuffers/archive/v$version.tar.gz \
   && tar -xzf v$version.tar.gz \
   && cd flatbuffers-$version \
   && mkdir build \
   && cd build \
   && cmake -G "Unix Makefiles" -DFLATBUFFERS_BUILD_TESTS=Off -DFLATBUFFERS_INSTALL=On -DCMAKE_BUILD_TYPE=Release -DFLATBUFFERS_BUILD_FLATHASH=Off .. \
   && make install -j$(nproc) \
   && cd ../../ \
   && rm -rf flatbuffers-$version \
   && rm v$version.tar.gz

# Update path so it uses gcc 9.2
ENV PATH="/usr/local/bin:${PATH}"

# Install zlib
RUN wget -O zlib.tar.gz 'https://zlib.net/fossils/zlib-1.2.8.tar.gz' \
   && tar xvzf zlib.tar.gz \
   && cd zlib-1.2.8 \
   && ./configure --static --archs=-fPIC \
   && make -j$(nproc) \
   && make install \
   && cd .. && rm -rf zlib*

# Install boost (use bjam -j16 on your beefy machine)
RUN wget -O boost.tar.gz 'https://sourceforge.net/projects/boost/files/boost/1.70.0/boost_1_70_0.tar.gz/download' \
   && tar -xvzf boost.tar.gz \
   && mkdir boost_output \
   && cd boost_1_70_0 \
   && ./bootstrap.sh --prefix=/boost_output --with-libraries=program_options,system,thread,test,chrono,date_time,atomic \
   && ./bjam -j$(nproc) cxxflags=-fPIC cflags=-fPIC -a install \
   && /usr/bin/cp -f /boost_output/lib/libboost_system.a /boost_output/lib/libboost_program_options.a /usr/lib64 \
   && cd .. && rm -rf boost_1_70_0 boost.tar.gz

# Download maven dependencies
RUN wget https://raw.githubusercontent.com/VowpalWabbit/vowpal_wabbit/master/java/pom.xml.in \
   && mvn dependency:resolve -f pom.xml.in \
   && rm -f pom.xml.in

# Non-layer configuration
# Set environment variables used by build
ENV LD_LIBRARY_PATH="/usr/local/lib64:${LD_LIBRARY_PATH}"
ENV JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
ENV BOOSTROOT=/boost_output
ENV PATH="/usr/local/libexec/gcc/x86_64-pc-linux-gnu/9.2.0:${PATH}"
