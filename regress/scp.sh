#	$OpenBSD: scp.sh,v 1.14 2022/05/15 23:48:07 djm Exp $
#	Placed in the Public Domain.

tid="scp"

#set -x

# Figure out if diff understands "-N"
if diff -N ${SRC}/scp.sh ${SRC}/scp.sh 2>/dev/null; then
	DIFFOPT="-rN"
else
	DIFFOPT="-r"
fi

COPY2=${OBJ}/copy2
DIR=${COPY}.dd
DIR2=${COPY}.dd2

SRC=`dirname ${SCRIPT}`
cp ${SRC}/scp-ssh-wrapper.sh ${OBJ}/scp-ssh-wrapper.scp
chmod 755 ${OBJ}/scp-ssh-wrapper.scp
export SCP # used in scp-ssh-wrapper.scp

scpclean() {
	rm -rf ${COPY} ${COPY2} ${DIR} ${DIR2}
	mkdir ${DIR} ${DIR2}
	chmod 755 ${DIR} ${DIR2}
}

for mode in scp sftp ; do
	tag="$tid: $mode mode"
	# scpopts should be an array to preverse the double quotes
	if [ "$os" == "windows" ]; then
		if test $mode = scp ; then
			scpopts=(-O -q -S "$TEST_SHELL_PATH ${OBJ}/scp-ssh-wrapper.scp")
		else
			scpopts=(-s -D ${SFTPSERVER})
		fi
	else
		if test $mode = scp ; then
			scpopts="-O -q -S ${OBJ}/scp-ssh-wrapper.scp"
		else
			scpopts="-s -D ${SFTPSERVER}"
		fi	
	fi

	verbose "tid: simple copy local file to local file"
	scpclean
	$SCP "${scpopts[@]}" ${DATA} ${COPY} 2>&1 1>/dev/null || fail "copy failed"
	cmp ${DATA} ${COPY} || fail "corrupted copy"

	verbose "$tag: simple copy local file to remote file"
	scpclean
	$SCP "${scpopts[@]}" ${DATA} somehost:${COPY} || fail "copy failed"
	cmp ${DATA} ${COPY} || fail "corrupted copy"

	verbose "$tag: simple copy remote file to local file"
	scpclean
	$SCP "${scpopts[@]}" somehost:${DATA} ${COPY} || fail "copy failed"
	cmp ${DATA} ${COPY} || fail "corrupted copy"

	# In place tests will not work on Windows because of simultaneous read of/write to file

	# verbose "$tag: copy local file to remote file in place"
	# scpclean
	# cp ${DATA} ${COPY}
	# $SCP "${scpopts[@]}" ${COPY} somehost:${COPY} || fail "copy failed"
	# cmp ${DATA} ${COPY} || fail "corrupted copy"

	# verbose "$tag: copy remote file to local file in place"
	# scpclean
	# cp ${DATA} ${COPY}
	# $SCP "${scpopts[@]}" somehost:${COPY} ${COPY} || fail "copy failed"
	# cmp ${DATA} ${COPY} || fail "corrupted copy"

	verbose "$tag: copy local file to remote file clobber"
	scpclean
	cat ${DATA} ${DATA} > ${COPY}
	$SCP "${scpopts[@]}" ${DATA} somehost:${COPY} || fail "copy failed"
	ls -l $DATA $COPY
	cmp ${DATA} ${COPY} || fail "corrupted copy"

	verbose "$tag: copy remote file to local file clobber"
	scpclean
	cat ${DATA} ${DATA} > ${COPY}
	$SCP "${scpopts[@]}" somehost:${DATA} ${COPY} || fail "copy failed"
	cmp ${DATA} ${COPY} || fail "corrupted copy"

	verbose "$tag: simple copy local file to remote dir"
	scpclean
	cp ${DATA} ${COPY}
	$SCP "${scpopts[@]}" ${COPY} somehost:${DIR} || fail "copy failed"
	cmp ${COPY} ${DIR}/copy || fail "corrupted copy"

	verbose "$tag: simple copy local file to local dir"
	scpclean
	cp ${DATA} ${COPY}
	$SCP "${scpopts[@]}" ${COPY} ${DIR} 2>&1 1>/dev/null || fail "copy failed"
	cmp ${COPY} ${DIR}/copy || fail "corrupted copy"

	verbose "$tag: simple copy remote file to local dir"
	scpclean
	cp ${DATA} ${COPY}
	$SCP "${scpopts[@]}" somehost:${COPY} ${DIR} || fail "copy failed"
	cmp ${COPY} ${DIR}/copy || fail "corrupted copy"

	verbose "$tag: recursive local dir to remote dir"
	scpclean
	rm -rf ${DIR2}
	cp ${DATA} ${DIR}/copy
	$SCP "${scpopts[@]}" -r ${DIR} somehost:${DIR2} || fail "copy failed"
	diff ${DIFFOPT} ${DIR} ${DIR2} || fail "corrupted copy"

	verbose "$tag: recursive local dir to local dir"
	scpclean
	rm -rf ${DIR2}
	cp ${DATA} ${DIR}/copy
	$SCP "${scpopts[@]}" -r ${DIR} ${DIR2} 2>&1 1>/dev/null || fail "copy failed"
	diff ${DIFFOPT} ${DIR} ${DIR2} || fail "corrupted copy"

	verbose "$tag: recursive remote dir to local dir"
	scpclean
	rm -rf ${DIR2}
	cp ${DATA} ${DIR}/copy
	$SCP "${scpopts[@]}" -r somehost:${DIR} ${DIR2} || fail "copy failed"
	diff ${DIFFOPT} ${DIR} ${DIR2} || fail "corrupted copy"

	verbose "$tag: shell metacharacters"
	scpclean
	(cd ${DIR} && \
	 touch '`touch metachartest`' && \
	 $SCP "${scpopts[@]}" *metachar* ${DIR2} 2>&1 2>/dev/null; \
	 [ ! -f metachartest ] ) || fail "shell metacharacters"

	if test $mode = scp ; then
		verbose "$tag: input args & printf check"
		scpclean
		cp ${DATA} ${COPY}
		$SCP "${scpopts[@]}" -vvv -o '"%h %p"' ${COPY} somehost:${DIR} 2>&1 | tee scp_printf_test.txt
		# relies on debug log statement, specifically from "debug3: spawning..." 
		[[ " $( cat "scp_printf_test.txt" ) " =~ "%h %p" ]] || fail "input args & printf check failed"
		rm -f scp_printf_test.txt
	fi

	if [ ! -z "$SUDO" ]; then
		verbose "$tag: skipped file after scp -p with failed chown+utimes"
		scpclean
		cp -p ${DATA} ${DIR}/copy
		cp -p ${DATA} ${DIR}/copy2
		cp ${DATA} ${DIR2}/copy
		chmod 660 ${DIR2}/copy
		$SUDO chown root ${DIR2}/copy
		$SCP -p "${scpopts[@]}" somehost:${DIR}/\* ${DIR2} >/dev/null 2>&1
		$SUDO diff ${DIFFOPT} ${DIR} ${DIR2} || fail "corrupted copy"
		$SUDO rm ${DIR2}/copy
	fi

	for i in 0 1 2 3 4 5 6 7; do
		verbose "$tag: disallow bad server #$i"
		SCPTESTMODE=badserver_$i
		export DIR SCPTESTMODE
		scpclean
		$SCP "${scpopts[@]}" somehost:${DATA} ${DIR} >/dev/null 2>/dev/null
		[ -d {$DIR}/rootpathdir ] && fail "allows dir relative to root dir"
		[ -d ${DIR}/dotpathdir ] && fail "allows dir creation in non-recursive mode"

		scpclean
		$SCP -r "${scpopts[@]}" somehost:${DATA} ${DIR2} >/dev/null 2>/dev/null
		[ -d ${DIR}/dotpathdir ] && fail "allows dir creation outside of subdir"

		scpclean
		$SCP -pr "${scpopts[@]}" somehost:${DATA} ${DIR2} >/dev/null 2>/dev/null
		[ ! -w ${DIR2} ] && fail "allows target root attribute change"

		scpclean
		$SCP "${scpopts[@]}" somehost:${DATA} ${DIR2} >/dev/null 2>/dev/null
		[ -e ${DIR2}/extrafile ] && fail "allows unauth object creation"
		rm -f ${DIR2}/extrafile
	done

	verbose "$tag: detect non-directory target"
	scpclean
	echo a > ${COPY}
	echo b > ${COPY2}
	$SCP "${scpopts[@]}" ${DATA} ${COPY} ${COPY2}
	cmp ${COPY} ${COPY2} >/dev/null && fail "corrupt target"
done

scpclean
rm -f ${OBJ}/scp-ssh-wrapper.scp
