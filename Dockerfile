FROM jupyter/all-spark-notebook:033056e6d164

# last update: Tue Jun  4 14:57:52 EDT 2019

USER root

RUN apt-get update \
  && apt-get install -y build-essential \
  && git clone https://github.com/rakudo/rakudo.git -b 2019.03.1 \
  && cd rakudo && perl Configure.pl --prefix=/usr --gen-moar --gen-nqp --backends=moar \
  && make && make install && cd .. && rm -rf rakudo \
  && export PATH=$PATH:/usr/share/perl6/site/bin \
  && git clone https://github.com/ugexe/zef.git \
     && cd zef && perl6 -Ilib bin/zef install . \
     && cd .. && rm -rf zef \
  && zef -v install https://github.com/bduggan/p6-jupyter-kernel.git@master \
  && zef -v install SVG::Plot --force-test \
  && git clone https://github.com/bduggan/p6-jupyter-kernel.git \
  && mv p6-jupyter-kernel/eg . && rm -rf p6-jupyter-kernel \
  && chown -R $NB_USER:$NB_GID eg \
  && fix-permissions eg \
  && jupyter-kernel.p6 --generate-config

ENV PATH /usr/share/perl6/site/bin:$PATH
