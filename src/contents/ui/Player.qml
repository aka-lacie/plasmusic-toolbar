import QtQuick 2.15
import QtQml.Models 2.3
import org.kde.plasma.private.mpris as Mpris

QtObject {
    id: root

    property var mpris2Model: Mpris.Mpris2Model {
        readonly property alias preferredSourceIdentity: root.sourceIdentity

        onRowsInserted: () => {
            updatePlayerIndex(this);
            root._updatePlayerCount();
            root._normalizeViewedSourceIdentity();
        }
        onRowsRemoved: () => {
            root._updatePlayerCount();
            root._normalizeViewedSourceIdentity();
        }
        onPreferredSourceIdentityChanged: () => updatePlayerIndex(this)

        function updatePlayerIndex(model) {
            if (!preferredSourceIdentity) {
                // Choose the multiplex source when no preferred source is set
                model.currentIndex = 0;
                return;
            }

            const CONTAINER_ROLE = Qt.UserRole + 1;
            for (let i = 1; i < model.rowCount(); i++) {
                const player = model.data(model.index(i, 0), CONTAINER_ROLE);
                if (player.identity === preferredSourceIdentity) {
                    model.currentIndex = i;
                    return;
                }
            }
        }
    }

    property var sourceIdentity: null
    property string viewedSourceIdentity: ""
    property bool exclusivePlayback: true
    property string pendingExclusiveIdentity: ""
    property int pendingExclusiveChecksRemaining: 0

    readonly property bool ready: {
        if (!mpris2Model.currentPlayer) {
            return false;
        }
        return mpris2Model.currentPlayer.identity === sourceIdentity || !sourceIdentity;
    }
    readonly property var previewPlayer: ready ? mpris2Model.currentPlayer : null
    readonly property var fullViewPlayer: playerForIdentity(viewedSourceIdentity) || previewPlayer

    readonly property string artists: ready ? mpris2Model.currentPlayer.artist : ""
    readonly property string title: ready ? mpris2Model.currentPlayer.track : ""
    readonly property string album: ready ? mpris2Model.currentPlayer.album : ""
    readonly property int playbackStatus: ready ? mpris2Model.currentPlayer.playbackStatus : Mpris.PlaybackStatus.Unknown
    readonly property int shuffle: ready ? mpris2Model.currentPlayer.shuffle : Mpris.ShuffleStatus.Unknown
    readonly property string artUrl: ready ? mpris2Model.currentPlayer.artUrl : ""
    readonly property int loopStatus: ready ? mpris2Model.currentPlayer.loopStatus : Mpris.LoopStatus.Unknown
    readonly property double songPosition: ready ? mpris2Model.currentPlayer.position : 0
    readonly property double songLength: ready ? mpris2Model.currentPlayer.length : 0
    readonly property real volume: ready ? mpris2Model.currentPlayer.volume : 0
    readonly property string identity: ready ? mpris2Model.currentPlayer.identity : ""

    readonly property bool canGoNext: ready ? mpris2Model.currentPlayer.canGoNext : false
    readonly property bool canGoPrevious: ready ? mpris2Model.currentPlayer.canGoPrevious : false
    readonly property bool canPlay: ready ? mpris2Model.currentPlayer.canPlay : false
    readonly property bool canPause: ready ? mpris2Model.currentPlayer.canPause : false
    readonly property bool canSeek: ready ? mpris2Model.currentPlayer.canSeek : false
    readonly property bool canRaise: ready ? mpris2Model.currentPlayer.canRaise : false

    // To know whether Shuffle and Loop can be changed we have to check if the property is defined,
    // unlike the other commands, LoopStatus and Shuffle hasn't a specific propety such as
    // CanPause, CanSeek, etc.
    readonly property bool canChangeShuffle: ready ? mpris2Model.currentPlayer.shuffle != undefined : false
    readonly property bool canChangeLoopStatus: ready ? mpris2Model.currentPlayer.loopStatus != undefined : false

    property Timer pendingExclusiveTimer: Timer {
        interval: 100
        repeat: true
        running: false
        onTriggered: root._applyPendingExclusivePlayback()
    }

    function playPause() {
        mpris2Model.currentPlayer?.PlayPause();
    }

    function previewPlayOrPause() {
        _clearPendingExclusivePlayback();
        if (playbackStatus === Mpris.PlaybackStatus.Playing) {
            playPause();
        } else {
            _playTarget(previewPlayer);
        }
    }

    function setPosition(position) {
        mpris2Model.currentPlayer.position = position;
    }

    function next() {
        const targetPlayer = previewPlayer;
        if (!targetPlayer) {
            return;
        }
        _clearPendingExclusivePlayback();
        targetPlayer.Next();
        _scheduleExclusivePlaybackAfterTransport(targetPlayer);
    }

    function previous() {
        const targetPlayer = previewPlayer;
        if (!targetPlayer) {
            return;
        }
        _clearPendingExclusivePlayback();
        targetPlayer.Previous();
        _scheduleExclusivePlaybackAfterTransport(targetPlayer);
    }

    function updatePosition() {
        mpris2Model.currentPlayer?.updatePosition();
    }

    function setVolume(volume) {
        mpris2Model.currentPlayer.volume = volume;
    }

    function changeVolume(delta, showOSD) {
        mpris2Model.currentPlayer.changeVolume(delta, showOSD);
    }

    function setShuffle(shuffle) {
        mpris2Model.currentPlayer.shuffle = shuffle;
    }

    function setLoopStatus(loopStatus) {
        mpris2Model.currentPlayer.loopStatus = loopStatus;
    }

    function raise() {
        mpris2Model.currentPlayer.Raise();
    }

    // Player switching support
    property int playerCount: 0
    readonly property int fullViewModelIndex: modelIndexForIdentity(fullViewIdentity)
    readonly property string fullViewIdentity: fullViewPlayer ? fullViewPlayer.identity : ""
    readonly property string fullViewArtists: fullViewPlayer ? fullViewPlayer.artist : ""
    readonly property string fullViewTitle: fullViewPlayer ? fullViewPlayer.track : ""
    readonly property string fullViewAlbum: fullViewPlayer ? fullViewPlayer.album : ""
    readonly property int fullViewPlaybackStatus: fullViewPlayer ? fullViewPlayer.playbackStatus : Mpris.PlaybackStatus.Unknown
    readonly property int fullViewShuffle: fullViewPlayer ? fullViewPlayer.shuffle : Mpris.ShuffleStatus.Unknown
    readonly property string fullViewArtUrl: fullViewPlayer ? fullViewPlayer.artUrl : ""
    readonly property int fullViewLoopStatus: fullViewPlayer ? fullViewPlayer.loopStatus : Mpris.LoopStatus.Unknown
    readonly property double fullViewSongPosition: fullViewPlayer ? fullViewPlayer.position : 0
    readonly property double fullViewSongLength: fullViewPlayer ? fullViewPlayer.length : 0
    readonly property real fullViewVolume: fullViewPlayer ? fullViewPlayer.volume : 0
    readonly property bool fullViewCanGoNext: fullViewPlayer ? fullViewPlayer.canGoNext : false
    readonly property bool fullViewCanGoPrevious: fullViewPlayer ? fullViewPlayer.canGoPrevious : false
    readonly property bool fullViewCanPlay: fullViewPlayer ? fullViewPlayer.canPlay : false
    readonly property bool fullViewCanPause: fullViewPlayer ? fullViewPlayer.canPause : false
    readonly property bool fullViewCanSeek: fullViewPlayer ? fullViewPlayer.canSeek : false
    readonly property bool fullViewCanRaise: fullViewPlayer ? fullViewPlayer.canRaise : false
    readonly property bool fullViewCanChangeShuffle: fullViewPlayer ? fullViewPlayer.shuffle != undefined : false
    readonly property bool fullViewCanChangeLoopStatus: fullViewPlayer ? fullViewPlayer.loopStatus != undefined : false

    function _updatePlayerCount() {
        playerCount = Math.max(0, mpris2Model.rowCount() - 1);
    }

    function modelIndexForIdentity(identity) {
        if (!identity) {
            return -1;
        }

        const CONTAINER_ROLE = Qt.UserRole + 1;
        for (let i = 1; i < mpris2Model.rowCount(); i++) {
            const player = mpris2Model.data(mpris2Model.index(i, 0), CONTAINER_ROLE);
            if (player && player.identity === identity) {
                return i;
            }
        }
        return -1;
    }

    function playerForIdentity(identity) {
        const modelIndex = modelIndexForIdentity(identity);
        return modelIndex !== -1 ? getPlayerAt(modelIndex) : null;
    }

    function _normalizeViewedSourceIdentity() {
        if (viewedSourceIdentity && !playerForIdentity(viewedSourceIdentity)) {
            viewedSourceIdentity = "";
        }
    }

    function viewPlayer(modelIndex) {
        const target = getPlayerAt(modelIndex);
        viewedSourceIdentity = target ? target.identity : "";
    }

    function returnToAutoFollow() {
        viewedSourceIdentity = "";
    }

    function getPlayerAt(modelIndex) {
        const CONTAINER_ROLE = Qt.UserRole + 1;
        return mpris2Model.data(mpris2Model.index(modelIndex, 0), CONTAINER_ROLE);
    }

    function isBrowsablePlayer(modelIndex) {
        const candidate = getPlayerAt(modelIndex);
        if (!candidate) {
            return false;
        }

        const hasPlaybackActivity = candidate.playbackStatus === Mpris.PlaybackStatus.Playing
            || candidate.playbackStatus === Mpris.PlaybackStatus.Paused;
        const hasTransportControls = candidate.canPlay
            || candidate.canPause
            || candidate.canGoNext
            || candidate.canGoPrevious
            || candidate.canSeek;
        const hasMediaMetadata = !!candidate.track
            || !!candidate.artist
            || !!candidate.album
            || !!candidate.artUrl
            || candidate.length > 0;

        return hasPlaybackActivity || hasTransportControls || hasMediaMetadata;
    }

    function fullViewPlayPause() {
        fullViewPlayer?.PlayPause();
    }

    function fullViewPlayOrPause() {
        _clearPendingExclusivePlayback();
        if (fullViewPlaybackStatus === Mpris.PlaybackStatus.Playing) {
            fullViewPlayPause();
        } else {
            _playTarget(fullViewPlayer);
        }
    }

    function fullViewSetPosition(position) {
        if (fullViewPlayer) {
            fullViewPlayer.position = position;
        }
    }

    function fullViewNext() {
        const targetPlayer = fullViewPlayer;
        if (!targetPlayer) {
            return;
        }
        _clearPendingExclusivePlayback();
        targetPlayer.Next();
        _scheduleExclusivePlaybackAfterTransport(targetPlayer);
    }

    function fullViewPrevious() {
        const targetPlayer = fullViewPlayer;
        if (!targetPlayer) {
            return;
        }
        _clearPendingExclusivePlayback();
        targetPlayer.Previous();
        _scheduleExclusivePlaybackAfterTransport(targetPlayer);
    }

    function fullViewUpdatePosition() {
        fullViewPlayer?.updatePosition();
    }

    function fullViewSetVolume(volume) {
        if (fullViewPlayer) {
            fullViewPlayer.volume = volume;
        }
    }

    function fullViewChangeVolume(delta, showOSD) {
        fullViewPlayer?.changeVolume(delta, showOSD);
    }

    function fullViewSetShuffle(shuffle) {
        if (fullViewPlayer) {
            fullViewPlayer.shuffle = shuffle;
        }
    }

    function fullViewSetLoopStatus(loopStatus) {
        if (fullViewPlayer) {
            fullViewPlayer.loopStatus = loopStatus;
        }
    }

    function fullViewRaise() {
        fullViewPlayer?.Raise();
    }

    function _clearPendingExclusivePlayback() {
        pendingExclusiveIdentity = "";
        pendingExclusiveChecksRemaining = 0;
        pendingExclusiveTimer.stop();
    }

    function _scheduleExclusivePlaybackAfterTransport(targetPlayer) {
        if (!exclusivePlayback || !targetPlayer || !targetPlayer.identity) {
            return;
        }

        pendingExclusiveIdentity = targetPlayer.identity;
        pendingExclusiveChecksRemaining = 5;
        pendingExclusiveTimer.restart();
    }

    function _applyPendingExclusivePlayback() {
        if (!pendingExclusiveIdentity) {
            _clearPendingExclusivePlayback();
            return;
        }

        const targetPlayer = playerForIdentity(pendingExclusiveIdentity);
        if (!targetPlayer) {
            _clearPendingExclusivePlayback();
            return;
        }

        if (targetPlayer.playbackStatus === Mpris.PlaybackStatus.Playing) {
            _pauseOtherPlayers(targetPlayer);
            _clearPendingExclusivePlayback();
            return;
        }

        pendingExclusiveChecksRemaining -= 1;
        if (pendingExclusiveChecksRemaining <= 0) {
            _clearPendingExclusivePlayback();
        }
    }

    function _pauseOtherPlayers(targetPlayer) {
        if (!targetPlayer) {
            return;
        }

        const CONTAINER_ROLE = Qt.UserRole + 1;
        for (let i = 1; i < mpris2Model.rowCount(); i++) {
            const other = mpris2Model.data(mpris2Model.index(i, 0), CONTAINER_ROLE);
            if (!other || other === targetPlayer) {
                continue;
            }
            if (other.playbackStatus === Mpris.PlaybackStatus.Playing) {
                other.Pause();
            }
        }
    }

    function _playTarget(targetPlayer) {
        if (!targetPlayer) {
            return;
        }

        if (exclusivePlayback) {
            _pauseOtherPlayers(targetPlayer);
        }
        targetPlayer.Play();
    }

    // Pause all other players, then play/resume the current one
    function fullViewPlayExclusive() {
        _playTarget(fullViewPlayer);
    }
}
