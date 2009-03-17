from afs cimport *

cdef import from "afs/ptuser.h":
    enum:
        PR_MAXNAMELEN
        PRGRP
        PRUSERS
        PRGROUPS
        ANONYMOUSID

    ctypedef char prname[PR_MAXNAMELEN]

    struct namelist:
        unsigned int namelist_len
        prname *namelist_val

    struct prlist:
        unsigned int prlist_len
        afs_int32 *prlist_val

    struct idlist:
        unsigned int idlist_len
        afs_int32 *idlist_val

    struct prcheckentry:
        afs_int32 flags
        afs_int32 id
        afs_int32 owner
        afs_int32 creator
        afs_int32 ngroups
        afs_int32 nusers
        afs_int32 count

    struct prlistentries:
        afs_int32 flags
        afs_int32 id
        afs_int32 owner
        afs_int32 creator
        afs_int32 ngroups
        afs_int32 nusers
        afs_int32 count

    struct prentries:
        unsigned int prentries_len
        prlistentries *prentries_val

    int ubik_PR_NameToID(ubik_client *, afs_int32, namelist *, idlist *)
    int ubik_PR_IDToName(ubik_client *, afs_int32, idlist *, namelist *)
    int ubik_PR_INewEntry(ubik_client *, afs_int32, char *, afs_int32, afs_int32)
    int ubik_PR_NewEntry(ubik_client *, afs_int32, char *, afs_int32, afs_int32, afs_int32 *)
    int ubik_PR_Delete(ubik_client *, afs_int32, afs_int32)
    int ubik_PR_AddToGroup(ubik_client *, afs_int32, afs_int32, afs_int32)
    int ubik_PR_RemoveFromGroup(ubik_client *, afs_int32, afs_int32, afs_int32)
    int ubik_PR_ListElements(ubik_client *, afs_int32, afs_int32, prlist *, afs_int32 *)
    int ubik_PR_ListOwned(ubik_client *, afs_int32, afs_int32, prlist *, afs_int32 *)
    int ubik_PR_ListEntry(ubik_client *, afs_int32, afs_int32, prcheckentry *)
    int ubik_PR_ChangeEntry(ubik_client *, afs_int32, afs_int32, char *, afs_int32, afs_int32)
    int ubik_PR_IsAMemberOf(ubik_client *, afs_int32, afs_int32, afs_int32, afs_int32 *)
    int ubik_PR_ListMax(ubik_client *, afs_int32, afs_int32 *, afs_int32 *)
    int ubik_PR_SetMax(ubik_client *, afs_int32, afs_int32, afs_int32)
    int ubik_PR_ListEntries(ubik_client *, afs_int32, afs_int32, afs_int32, prentries *, afs_int32 *)

cdef import from "afs/pterror.h":
    enum:
        PRNOENT
        PRTOOMANY

    void initialize_PT_error_table()

cdef class PTEntry:
    cdef public afs_int32 flags
    cdef public afs_int32 id
    cdef public afs_int32 owner
    cdef public afs_int32 creator
    cdef public afs_int32 ngroups
    cdef public afs_int32 nusers
    cdef public afs_int32 count

    def __repr__(self):
        return '<PTEntry: %s>' % self.id

cdef int _ptentry_from_checkentry(PTEntry p_entry, prcheckentry c_entry) except -1:
    if p_entry is None:
        raise TypeError
        return -1

    p_entry.flags = c_entry.flags
    p_entry.id = c_entry.id
    p_entry.owner = c_entry.owner
    p_entry.creator = c_entry.creator
    p_entry.ngroups = c_entry.ngroups
    p_entry.nusers = c_entry.nusers
    p_entry.count = c_entry.count
    return 0

cdef int _ptentry_to_checkentry(prcheckentry * c_entry, PTEntry p_entry) except -1:
    if p_entry is None:
        raise TypeError
        return -1

    c_entry.flags = p_entry.flags
    c_entry.id = p_entry.id
    c_entry.owner = p_entry.owner
    c_entry.creator = p_entry.creator
    c_entry.ngroups = p_entry.ngroups
    c_entry.nusers = p_entry.nusers
    c_entry.count = p_entry.count
    return 0

cdef int _ptentry_from_listentry(PTEntry p_entry, prlistentries c_entry) except -1:
    if p_entry is None:
        raise TypeError
        return -1

    p_entry.flags = c_entry.flags
    p_entry.id = c_entry.id
    p_entry.owner = c_entry.owner
    p_entry.creator = c_entry.creator
    p_entry.ngroups = c_entry.ngroups
    p_entry.nusers = c_entry.nusers
    p_entry.count = c_entry.count
    return 0

cdef int _ptentry_to_listentry(prlistentries * c_entry, PTEntry p_entry) except -1:
    if p_entry is None:
        raise TypeError
        return -1

    c_entry.flags = p_entry.flags
    c_entry.id = p_entry.id
    c_entry.owner = p_entry.owner
    c_entry.creator = p_entry.creator
    c_entry.ngroups = p_entry.ngroups
    c_entry.nusers = p_entry.nusers
    c_entry.count = p_entry.count
    return 0

cdef class PTS:
    """
    A PTS object is essentially a handle to talk to the server in a
    given cell.

    cell defaults to None. If no argument is passed for cell, PTS
    connects to the home cell.

    sec is the security level, an integer from 0 to 3:
      - 0: unauthenticated connection
      - 1: try authenticated, then fall back to unauthenticated
      - 2: fail if an authenticated connection can't be established
      - 3: same as 2, plus encrypt all traffic to the protection
        server
    """
    cdef ubik_client * client

    def __cinit__(self, cell=None, sec=1):
        cdef afs_int32 code
        cdef afsconf_dir *cdir
        cdef afsconf_cell info
        cdef char * c_cell
        cdef ktc_principal prin
        cdef ktc_token token
        cdef rx_securityClass *sc
        cdef rx_connection *serverconns[MAXSERVERS]
        cdef int i

        initialize_PT_error_table()

        if cell is None:
            c_cell = NULL
        else:
            c_cell = cell

        self.client = NULL

        code = rx_Init(0)
        if code != 0:
            raise Exception(code, "Error initializing Rx")

        cdir = afsconf_Open(AFSDIR_CLIENT_ETC_DIRPATH)
        if cdir is NULL:
            raise OSError(errno,
                          "Error opening configuration directory (%s): %s" % \
                              (AFSDIR_CLIENT_ETC_DIRPATH, strerror(errno)))
        code = afsconf_GetCellInfo(cdir, c_cell, "afsprot", &info)
        if code != 0:
            raise Exception(code, "GetCellInfo: %s" % afs_error_message(code))

        if sec > 0:
            strncpy(prin.cell, info.name, sizeof(prin.cell))
            prin.instance[0] = 0
            strncpy(prin.name, "afs", sizeof(prin.name))

            code = ktc_GetToken(&prin, &token, sizeof(token), NULL);
            if code != 0:
                if sec >= 2:
                    # No really - we wanted authentication
                    raise Exception(code, "Failed to get token for service AFS: %s" % afs_error_message(code))
                sec = 0
            else:
                if sec == 3:
                    level = rxkad_crypt
                else:
                    level = rxkad_clear
                sc = rxkad_NewClientSecurityObject(level, &token.sessionKey,
                                                   token.kvno, token.ticketLen,
                                                   token.ticket)

        if sec == 0:
            sc = rxnull_NewClientSecurityObject()
        else:
            sec = 2

        memset(serverconns, 0, sizeof(serverconns))
        for 0 <= i < info.numServers:
            serverconns[i] = rx_NewConnection(info.hostAddr[i].sin_addr.s_addr,
                                              info.hostAddr[i].sin_port,
                                              PRSRV,
                                              sc,
                                              sec)

        code = ubik_ClientInit(serverconns, &self.client)
        if code != 0:
            raise Exception("Failed to initialize ubik connection to Protection server: %s" % afs_error_message(code))

        code = rxs_Release(sc)

    def __dealloc__(self):
        ubik_ClientDestroy(self.client)
        rx_Finalize()

    def NameToId(self, name):
        """
        Converts a user or group to an AFS ID.
        """
        cdef namelist lnames
        cdef idlist lids
        cdef afs_int32 code, id
        name = name.lower()

        lids.idlist_len = 0
        lids.idlist_val = NULL
        lnames.namelist_len = 1
        lnames.namelist_val = <prname *>malloc(PR_MAXNAMELEN)
        strncpy(lnames.namelist_val[0], name, PR_MAXNAMELEN)
        code = ubik_PR_NameToID(self.client, 0, &lnames, &lids)
        if lids.idlist_val is not NULL:
            id = lids.idlist_val[0]
            free(lids.idlist_val)
        if id == ANONYMOUSID:
            code = PRNOENT
        if code != 0:
            raise Exception("Failed to lookup PTS name: %s" % afs_error_message(code))
        return id

    def IdToName(self, id):
        """
        Convert an AFS ID to the name of a user or group.
        """
        cdef namelist lnames
        cdef idlist lids
        cdef afs_int32 code
        cdef char name[PR_MAXNAMELEN]

        lids.idlist_len = 1
        lids.idlist_val = <afs_int32 *>malloc(sizeof(afs_int32))
        lids.idlist_val[0] = id
        lnames.namelist_len = 0
        lnames.namelist_val = NULL
        code = ubik_PR_IDToName(self.client, 0, &lids, &lnames)
        if lnames.namelist_val is not NULL:
            strncpy(name, lnames.namelist_val[0], sizeof(name))
            free(lnames.namelist_val)
        if lids.idlist_val is not NULL:
            free(lids.idlist_val)
        if name == str(id):
            code = PRNOENT
        if code != 0:
            raise Exception("Failed to lookup PTS ID: %s" % afs_error_message(code))
        return name

    def CreateUser(self, name, id=None):
        """
        Create a new user in the protection database. If an ID is
        provided, that one will be used.
        """
        cdef afs_int32 code
        cdef afs_int32 cid
        name = name[:PR_MAXNAMELEN].lower()

        if id is not None:
            cid = id

        if id is not None:
            code = ubik_PR_INewEntry(self.client, 0, name, cid, 0)
        else:
            code = ubik_PR_NewEntry(self.client, 0, name, 0, 0, &cid)

        if code != 0:
            raise Exception("Failed to create user: %s" % afs_error_message(code))
        return cid

    def CreateGroup(self, name, owner, id=None):
        """
        Create a new group in the protection database. If an ID is
        provided, that one will be used.
        """
        cdef afs_int32 code, cid

        name = name[:PR_MAXNAMELEN].lower()
        oid = self.NameToId(owner)

        if id is not None:
            cid = id
            code = ubik_PR_INewEntry(self.client, 0, name, cid, oid)
        else:
            code = ubik_PR_NewEntry(self.client, 0, name, PRGRP, oid, &cid)

        if code != 0:
            raise Exception("Failed to create group: %s" % afs_error_message(code))
        return cid

    def Delete(self, id):
        """
        Delete the protection database entry with the provided ID.
        """
        cdef afs_int32 code

        code = ubik_PR_Delete(self.client, 0, id)
        if code != 0:
            raise Exception("Failed to delete user: %s" % afs_error_message(code))

    def AddToGroup(self, uid, gid):
        """
        Add the user with the given ID to the group with the given ID.
        """
        cdef afs_int32 code

        code = ubik_PR_AddToGroup(self.client, 0, uid, gid)
        if code != 0:
            raise Exception("Failed to add user to group: %s" % afs_error_message(code))

    def RemoveFromGroup(self, uid, gid):
        """
        Remove the user with the given ID from the group with the given ID.
        """
        cdef afs_int32 code

        code = ubik_PR_RemoveFromGroup(self.client, 0, uid, gid)
        if code != 0:
            raise Exception("Failed to remove user from group: %s" % afs_error_message(code))

    def ListMembers(self, id):
        """
        Get the membership of an entity.

        If id is a group ID, this returns the users that are in that
        group.

        If id is a user ID, this returns the list of groups that user
        is on.

        This returns a list of PTS IDs.
        """
        cdef afs_int32 code, over
        cdef prlist alist
        cdef int i
        cdef object members = []

        alist.prlist_len = 0
        alist.prlist_val = NULL

        code = ubik_PR_ListElements(self.client, 0, id, &alist, &over)

        if alist.prlist_val is not NULL:
            for i in range(alist.prlist_len):
                members.append(alist.prlist_val[i])
            free(alist.prlist_val)

        if over:
            code = PRTOOMANY
        if code != 0:
            raise Exception("Failed to get group membership: %s" % afs_error_message(code))

        return members

    def ListOwned(self, oid):
        """
        Get all groups owned by an entity.
        """
        cdef afs_int32 code, over
        cdef prlist alist
        cdef int i
        cdef object owned = []

        alist.prlist_len = 0
        alist.prlist_val = NULL

        code = ubik_PR_ListOwned(self.client, 0, oid, &alist, &over)

        if alist.prlist_val is not NULL:
            for i in range(alist.prlist_len):
                owned.append(alist.prlist_val[i])
            free(alist.prlist_val)

        if over:
            code = PRTOOMANY
        if code != 0:
            raise Exception("Failed to get owned entities: %s" % afs_error_message(code))

        return owned

    def ListEntry(self, id):
        """
        Load a PTEntry instance with information about the provided
        ID.
        """
        cdef afs_int32 code
        cdef prcheckentry centry
        cdef object entry = PTEntry()

        code = ubik_PR_ListEntry(self.client, 0, id, &centry)
        if code != 0:
            raise Exception("Error getting entity info: %s" % afs_error_message(code))

        _ptentry_from_checkentry(entry, centry)
        return entry

    def ChangeEntry(self, id, newname=None, newid=None, newoid=None):
        """
        Change the name, ID, and/or owner of a PTS entity.

        For any of newname, newid, and newoid which aren't specified
        or ar None, the value isn't changed.
        """
        cdef afs_int32 code
        cdef afs_int32 c_newid = 0, c_newoid = 0
        cdef char * c_newname

        if newname is None:
            newname = self.IdToName(id)
        c_newname = newname
        if newid is not None:
            c_newid = newid
        if newoid is not None:
            c_newoid = newoid

        code = ubik_PR_ChangeEntry(self.client, 0, id, c_newname, c_newoid, c_newid)
        if code != 0:
            raise Exception("Error changing entity info: %s" % afs_error_message(code))

    def IsAMemberOf(self, uid, gid):
        """
        Return True if the given uid is a member of the given gid.
        """
        cdef afs_int32 code
        cdef afs_int32 flag

        code = ubik_PR_IsAMemberOf(self.client, 0, uid, gid, &flag)
        if code != 0:
            raise Exception("Error testing membership: %s" % afs_error_message(code))

        return bool(flag)

    def ListMax(self):
        """
        Return a tuple of the maximum user ID and the maximum group
        ID currently assigned.
        """
        cdef afs_int32 code, uid, gid

        code = ubik_PR_ListMax(self.client, 0, &uid, &gid)
        if code != 0:
            raise Exception("Error looking up max uid/gid: %s" % afs_error_message(code))

        return (uid, gid)

    def SetMaxUserId(self, id):
        """
        Set the maximum currently assigned user ID (the next
        automatically assigned UID will be id + 1)
        """
        cdef afs_int32 code

        code = ubik_PR_SetMax(self.client, 0, id, 0)
        if code != 0:
            raise Exception("Error setting max uid: %s" % afs_error_message(code))

    def SetMaxGroupId(self, id):
        """
        Set the maximum currently assigned user ID (the next
        automatically assigned UID will be id + 1)
        """
        cdef afs_int32 code

        code = ubik_PR_SetMax(self.client, 0, id, PRGRP)
        if code != 0:
            raise Exception("Error setting max gid: %s" % afs_error_message(code))

    def ListEntries(self, users=None, groups=None):
        """
        Return a list of PTEntry instances representing all entries in
        the PRDB.

        Returns just users by default, but can return just users, just
        groups, or both.
        """
        cdef afs_int32 code
        cdef afs_int32 flag = 0, startindex = 0, nentries, nextstartindex
        cdef prentries centries
        cdef unsigned int i

        cdef object entries = []

        if groups is None or users is True:
            flag |= PRUSERS
        if groups:
            flag |= PRGROUPS

        while startindex != -1:
            centries.prentries_val = NULL
            centries.prentries_len = 0
            nextstartindex = -1

            code = ubik_PR_ListEntries(self.client, 0, flag, startindex, &centries, &nextstartindex)
            if centries.prentries_val is not NULL:
                for i in range(centries.prentries_len):
                    e = PTEntry()
                    _ptentry_from_listentry(e, centries.prentries_val[i])
                    entries.append(e)
                free(centries.prentries_val)
            if code != 0:
                raise Exception("Unable to list entries: %s" % afs_error_message(code))

            startindex = nextstartindex

        return entries
