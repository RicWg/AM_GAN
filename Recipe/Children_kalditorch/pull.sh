diff -u core.py.org core.py > patch.core
diff -u data_io.py.org data_io.py > patch.data_io
diff -u run_exp.py.org run_exp.py > patch.run_exp
diff -u utils.py.org utils.py > patch.utils

mv -f core.py.org core.py
mv -f data_io.py.org data_io.py
mv -f run_exp.py.org run_exp.py
mv -f utils.py.org utils.py

git pull

cp core.py core.py.org
cp data_io.py data_io.py.org
cp run_exp.py run_exp.py.org
cp utils.py utils.py.org

patch -Np0 -i patch.core
patch -Np0 -i patch.data_io
patch -Np0 -i patch.run_exp
patch -Np0 -i patch.utils

mv -f patch.core patch.core.org
mv -f patch.data_io patch.data_io.org
mv -f patch.run_exp patch.run_exp.org
mv -f patch.utils patch.utils.org
