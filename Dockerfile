FROM jupyter/all-spark-notebook:033056e6d164

# last update: Mon Jan 22 09:34:22 EST 2018 

USER root

RUN apt-get update \
  && apt-get install -y build-essential \
  && git clone https://github.com/rakudo/rakudo.git -b 2017.12 \
  && cd rakudo && perl Configure.pl --prefix=/usr --gen-moar --gen-nqp --backends=moar \
  && make && make install && cd .. && rm -rf rakudo \
  && export PATH=$PATH:/usr/share/perl6/site/bin \
  && git clone https://github.com/ugexe/zef.git \
     && cd zef && perl6 -Ilib bin/zef install . \
     && cd .. && rm -rf zef \
  && zef -v install https://github.com/bduggan/p6-jupyter-kernel.git@0.0.9 \
  && zef -v install SVG::Plot --force-test \
  && git clone https://github.com/bduggan/p6-jupyter-kernel.git \
  && mv p6-jupyter-kernel/eg . && rm -rf p6-jupyter-kernel \
  && chown -R $NB_USER:$NB_GID eg \
  && fix-permissions eg \
  && jupyter-kernel.p6 --generate-config

ENV PATH /usr/share/perl6/site/bin:$PATH
