FROM jupyter/all-spark-notebook:033056e6d164

USER root

RUN apt-get update \
  && apt-get install -y build-essential \
  && git clone https://github.com/rakudo/rakudo.git -b 2017.12 \
  && cd rakudo && perl Configure.pl --prefix=/usr --gen-moar --gen-nqp --backends=moar \
  && make && make install && cd .. && rm -rf rakudo \
  && git clone https://github.com/ugexe/zef.git && cd zef && perl6 -Ilib bin/zef install . \
  && export PATH=$PATH:/usr/share/perl6/site/bin \
  && zef -v install Jupyter::Kernel SVG::Plot --force-test \
  && jupyter-kernel.p6 --generate-config

ENV PATH /usr/share/perl6/site/bin:$PATH
