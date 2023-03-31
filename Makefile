.PHONY: all convert execute resetnb delout clean jupyter

# Usage:
# make         # execute and convert all Jupyter notebooks
# make convert # only convert Jupyter notebooks
# make execute # only execute Jupyter notebooks
# make resetnb # only clear Jupyter notebook outputs
# make delout  # only remove converted files
# make clean   # combine resetnb and remove converted files
# make sync    # copy all recently converted files to _posts/ and assets/
# make unsync  # remove all recently converted files from _posts/ and assets/
# make reset   # the big daddy HARD RESET: completely reverses all changes
# make jupyter # startup docker container running Jupyter server
# make jekyll  # startup docker container running Jekyll server

################################################################################
# GLOBALS                                                                      #
################################################################################

# make cli args
OFRMT := markdown
THEME := dark
TMPLT := tessay.md
BASDR := jupyter
OUTDR := ${BASDR}/converted
INTDR := ${BASDR}/notebooks
TMPDR := ${BASDR}/templates
DCTNR := $(notdir $(PWD))
LGLVL := WARN
FGEXT := _files
FGSDR := 'assets/images/{notebook_name}${FGEXT}'
GITBR := master
GITRM := origin

# extensions available
OEXT_html     = html
OEXT_latex    = tex
OEXT_pdf      = pdf
OEXT_webpdf   = pdf
OEXT_markdown = md
OEXT_rst      = rst
OEXT_script   = py
OEXT_notebook = ipynb
OEXT = ${OEXT_${OFRMT}}

# individual conversion flag variables
LGLFL = --log-level ${LGLVL}
OUTFL = --to ${OFRMT}
THMFL = --theme ${THEME}
TMPFL = --template ${TMPLT}
ODRFL = --output-dir ${OUTDR}
FIGDR = --NbConvertApp.output_files_dir=${FGSDR}
XTRDR = --TemplateExporter.extra_template_basedirs=${TMPDR}
RMTGS = --TagRemovePreprocessor.enabled=True
RMCEL = --TagRemovePreprocessor.remove_cell_tags remove_cell
RMNPT = --TagRemovePreprocessor.remove_input_tags remove_input
RMIPT = --TemplateExporter.exclude_input_prompt=True
RMOPT = --TemplateExporter.exclude_output_prompt=True
RMWSP = --RegexRemovePreprocessor.patterns '\s*\Z'

# check for conditional vars
ifdef NOTMPLT
  undefine TMPFL
endif
ifdef NOTHEME
  undefine THMFL
endif

# combined conversion flag variables
TMPFLGS = ${OUTFL} ${THMFL} ${TMPFL} ${ODRFL} ${FIGDR} ${XTRDR}
RMVFLGS = ${RMTGS} ${RMCEL} ${RMNPT} ${RMIPT} ${RMOPT} ${RMWSP}

# final conversion flag variable
CNVRSNFLGS = ${LGLFL} ${TMPFLGS} ${RMVFLGS}

# notebook-related variables
CURRENTDIR := $(PWD)
NOTEBOOKS  := $(wildcard ${INTDR}/*.ipynb)
CONVERTNB  := $(addprefix ${OUTDR}/, $(notdir $(NOTEBOOKS:%.ipynb=%.${OEXT})))

# docker-related variables
JKLCTNR = jekyll.${DCTNR}
JPTCTNR = jupyter.${DCTNR}
DCKRIMG = ghcr.io/ragingtiger/omega-notebook:master
DCKRRUN = docker run --rm -v ${CURRENTDIR}:/home/jovyan -it ${DCKRIMG}

# check for conditional vars to turn off docker
ifdef NODOCKER
  undefine DCKRRUN
endif

# jupyter nbconvert vars
NBEXEC = jupyter nbconvert --to notebook --execute --inplace
NBCNVR = jupyter nbconvert ${CNVRSNFLGS}
NBCLER = jupyter nbconvert --clear-output --inplace

################################################################################
# COMMANDS                                                                     #
################################################################################

# defaults to converting all UN-converted notebooks
all: ${CONVERTNB}

# launch jupyter notebook development Docker image
jupyter:
	@ echo "Launching Jupyter in Docker container -> ${JPTCTNR} ..."
	@ docker run -d \
	           --rm \
	           --name ${JPTCTNR} \
	           -e JUPYTER_ENABLE_LAB=yes \
	           -p 8888 \
	           -v ${CURRENTDIR}:/home/jovyan \
	           ${DCKRIMG} && \
	sleep 5 && \
	  docker logs ${JPTCTNR} 2>&1 | \
	    grep "http://127.0.0.1" | tail -n 1 | \
	    sed "s/:8888/:$$(docker port ${JPTCTNR} | \
	    grep '0.0.0.0:' | awk '{print $$3'} | sed 's/0.0.0.0://g')/g"
	@ echo "${JPTCTNR}" >> .running_containers

# rule for executing single notebooks before converting
%.ipynb:
	@ echo "Executing ${INTDR}/$@ in place."
	@ ${DCKRRUN} ${NBEXEC} ${INTDR}/$@

# rule for converting single notebooks to HTML
${OUTDR}/%.${OEXT}: %.ipynb
	@ echo "Converting ${INTDR}/$< to ${OFRMT}"
	@ ${DCKRRUN} ${NBCNVR} ${INTDR}/$<

# execute all notebooks and store output inplace
execute:
	@ echo "Executing all Jupyter notebooks: ${NOTEBOOKS}"
	@ ${DCKRRUN} ${NBEXEC} ${NOTEBOOKS}

# convert all notebooks to HTML
convert:
	@ echo "Converting all Jupyter notebooks: ${NOTEBOOKS}"
	@ ${DCKRRUN} ${NBCNVR} ${NOTEBOOKS}

# sync all converted files to necessary locations in TEssay source
sync:
	@ echo "_posts/$$(ls ${OUTDR} | grep ".*\.${OEXT}$$")" \
	  >> ${BASDR}/.synced_history
	@ echo "assets/images/$$(ls ${OUTDR}/assets/images)" \
	  >> ${BASDR}/.synced_history
	@ echo "Moving all jupyter converted files to _posts/ and assets/ dirs."
	@ rsync -havP ${OUTDR}/*.${OEXT} ${CURRENTDIR}/_posts/
	@ rsync -havP ${OUTDR}/assets/ ${CURRENTDIR}/assets

# create jekyll static site
jekyll:
	@ echo "Launching Jekyll in Docker container -> ${JKLCTNR} ..."
	@ docker run -d \
	           --rm \
	           --name ${JKLCTNR} \
	           -v ${CURRENTDIR}:/srv/jekyll:Z \
	           -p 4000 \
	           jekyll/jekyll:4.2.0 \
	             jekyll serve && \
	sleep 5 && \
	   echo "Server address: http://0.0.0.0:$$(docker port ${JKLCTNR} | \
	    grep '0.0.0.0:' | awk '{print $$3'} | sed 's/0.0.0.0://g')"
	@ echo "${JKLCTNR}" >> .running_containers

# launch all docker containers
containers: jupyter jekyll

# stop all containers
stop-containers:
	@ while read container; do \
		echo -n "Stopping Docker container -> "; \
	  docker stop $$container; \
	done < ${CURRENTDIR}/.running_containers
	@ rm -f ${CURRENTDIR}/.running_containers

# unsync all converted files back to original locations
unsync:
	@ echo "Removing all jupyter converted files from _posts/ and assets/ dirs:"
	@ while read item; do \
	  if echo "$$item" | grep -q ".*\.${OEXT}$$"; then \
	    rm -f "$${item}"; \
	    echo "Removed -> $$item"; \
	  else \
	    rm -rf "$${item}"; \
	    echo "Removed -> $$item"; \
	  fi \
	done < ${BASDR}/.synced_history
	@ rm -f ${BASDR}/.synced_history

# remove output from executed notebooks
resetnb:
	@ echo "Removing all output from Jupyter notebooks."
	@ ${DCKRRUN} ${NBCLER} ${NOTEBOOKS}

# delete all converted files
delout:
	@ echo "Deleting all converted files."
	@ if [ -d "${CURRENTDIR}/${OUTDR}" ]; then \
	  rm -rf "${CURRENTDIR}/${OUTDR}"; \
	fi

# cleanup everything
clean: delout resetnb
	@ echo "Removing Jekyll static site directory."
	@ rm -rf ${CURRENTDIR}/_site

# reset to original state undoing all changes
reset: unsync clean
