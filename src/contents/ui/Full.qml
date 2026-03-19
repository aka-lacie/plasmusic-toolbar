import "./components"
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris
import Qt5Compat.GraphicalEffects


Item {
    id: root

    property bool playerSelectorVisible: player.playerCount > 1


    property string albumPlaceholder: plasmoid.configuration.albumPlaceholder
    property real volumeStep: plasmoid.configuration.volumeStep
    property bool albumCoverBackground: plasmoid.configuration.fullAlbumCoverAsBackground
    property bool thumbnailVisible: plasmoid.configuration.fullViewThumbnailVisible
    property bool progressBarVisible: plasmoid.configuration.fullViewProgressBarVisible
    property bool volumeControlVisible: plasmoid.configuration.fullViewVolumeControlVisible
    property bool shuffleVisible: plasmoid.configuration.fullViewShuffleVisible
    property bool playbackControlsVisible: plasmoid.configuration.fullViewPlaybackControlsVisible
    property bool loopVisible: plasmoid.configuration.fullViewLoopVisible
    property bool playbackControlsFitWidth: plasmoid.configuration.fullViewPlaybackControlsFillWidth
    property bool songTextVisible: plasmoid.configuration.fullViewSongTextVisible
    property int songTextAlignment: plasmoid.configuration.fullViewSongTextAlignment
    property bool songTextAboveProgressBar: plasmoid.configuration.fullViewSongTextPosition === SongAndArtistText.VerticalPosition.AboveProgressBar

    // The Full View max and min width is driven by config values. The window can be resized within these bounds; thumbnail and text adapt.
    readonly property int configMinWidth: plasmoid.configuration.fullViewMinWidth
    readonly property int maximumWidth: plasmoid.configuration.fullViewMaxWidth
    property bool fullAlbumCoverRounded: plasmoid.configuration.fullAlbumCoverRounded
    property int albumCoverRadius: plasmoid.configuration.fullAlbumCoverRadius

    // Override min width if visible content (e.g. playback controls) needs more space
    readonly property int contentMinWidth: row.visible ? row.implicitWidth + 40 : 0
    readonly property int effectiveMinWidth: Math.min(Math.max(configMinWidth, contentMinWidth), maximumWidth)

    Layout.preferredWidth: maximumWidth
    Layout.minimumWidth: effectiveMinWidth
    Layout.maximumWidth: maximumWidth
    Layout.preferredHeight: column.implicitHeight
    Layout.minimumHeight: column.implicitHeight
    Layout.maximumHeight: column.implicitHeight

    // Store the original theme colors (root keeps default Kirigami.Theme.inherit: true)
    readonly property color _originalTextColor: Kirigami.Theme.textColor
    readonly property color _originalHighlightColor: Kirigami.Theme.highlightColor

    Item {
        visible: albumCoverBackground && thumbnailVisible
        Layout.margins: 0
        anchors.centerIn: parent
        height: column.height
        width: column.width

        ImageWithPlaceholder {
            id: albumArtFull
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height * 0.7
            width: parent.width
            fillMode: Image.PreserveAspectCrop
            placeholderSource: albumPlaceholder
            imageSource: player.artUrl

            onStatusChanged: {
                if (status === Image.Ready) {
                    imageColors.update()
                }
            }

            Kirigami.ImageColors {
                id: imageColors
                source: albumArtFull
                readonly property color bgColor: average
                readonly property var bgColorBrightness: Kirigami.ColorUtils.brightnessForColor(bgColor)
                readonly property color contrastColor: bgColorBrightness === Kirigami.ColorUtils.Dark ? "white" : "black"
                readonly property color fgColor: Kirigami.ColorUtils.tintWithAlpha(bgColor, contrastColor, .6)
                readonly property color hlColor: Kirigami.ColorUtils.tintWithAlpha(bgColor, contrastColor, .8)
            }

            layer.enabled: root.fullAlbumCoverRounded && root.albumCoverRadius > 0
			layer.effect: OpacityMask {
				maskSource: Item {
					width: albumArtFull.width
					height: albumArtFull.height
					Rectangle {
						anchors.fill: parent
						radius: albumCoverRadius
                        bottomRightRadius: 0
                        bottomLeftRadius: 0
					}
				}
			}
        }

        LinearGradient {
            id: mask
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.4; color: "transparent" }
                GradientStop { position: 0.7; color: imageColors.bgColor }
                GradientStop { position: 1; color: imageColors.bgColor }
            }
        }
    }


    ColumnLayout {
        id: column

        spacing: 0
        anchors.fill: parent

        // Override theme ONLY for this layout and its children
        Kirigami.Theme.inherit: false
        Kirigami.Theme.textColor: albumCoverBackground ? imageColors.fgColor : root._originalTextColor
        Kirigami.Theme.highlightColor: albumCoverBackground ? imageColors.hlColor : root._originalHighlightColor

        Item {
            id: playerSelector
            visible: playerSelectorVisible
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            implicitWidth: playerRow.implicitWidth
            implicitHeight: playerRow.implicitHeight

            // Sliding highlight with stretch effect
            Rectangle {
                id: highlight
                height: parent.height
                radius: Kirigami.Units.cornerRadius
                color: Kirigami.Theme.textColor
                opacity: 0.15
                visible: activeButton !== null
                x: leftEdge
                width: Math.max(0, rightEdge - leftEdge)

                readonly property int leadDuration: 250
                readonly property int trailDelay: 80
                readonly property int trailDuration: leadDuration - trailDelay

                property Item activeButton: playerRepeater.activeItem
                property real targetLeft: activeButton ? activeButton.x : 0
                property real targetRight: activeButton ? activeButton.x + activeButton.width : 0
                property real leftEdge: targetLeft
                property real rightEdge: targetRight

                Behavior on leftEdge {
                    id: leftBehavior
                    NumberAnimation {
                        duration: leftBehavior.isTrailing ? highlight.trailDuration : highlight.leadDuration
                        easing.type: Easing.OutQuart
                    }
                    property bool isTrailing: false
                }
                Behavior on rightEdge {
                    id: rightBehavior
                    NumberAnimation {
                        duration: rightBehavior.isTrailing ? highlight.trailDuration : highlight.leadDuration
                        easing.type: Easing.OutQuart
                    }
                    property bool isTrailing: false
                }

                Timer {
                    id: trailingLeftTimer
                    interval: highlight.trailDelay
                    onTriggered: highlight.leftEdge = highlight.targetLeft
                }
                Timer {
                    id: trailingRightTimer
                    interval: highlight.trailDelay
                    onTriggered: highlight.rightEdge = highlight.targetRight
                }

                onTargetLeftChanged: {
                    if (targetLeft < leftEdge) {
                        trailingLeftTimer.stop()
                        leftBehavior.isTrailing = false
                        leftEdge = targetLeft
                    } else {
                        leftBehavior.isTrailing = true
                        trailingLeftTimer.restart()
                    }
                }
                onTargetRightChanged: {
                    if (targetRight > rightEdge) {
                        trailingRightTimer.stop()
                        rightBehavior.isTrailing = false
                        rightEdge = targetRight
                    } else {
                        rightBehavior.isTrailing = true
                        trailingRightTimer.restart()
                    }
                }
            }

            RowLayout {
                id: playerRow
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    id: playerRepeater
                    model: player.mpris2Model
                    property Item activeItem: null
                    delegate: Item {
                        required property string iconName
                        required property bool isMultiplexer
                        required property string identity
                        required property int index
                        readonly property bool hidden: {
                            if (isMultiplexer) return true;
                            // Hide non-media MPRIS sources (e.g. image viewers)
                            var p = player.getPlayerAt(index);
                            return p && !p.canSeek;
                        }
                        visible: !hidden
                        implicitWidth: hidden ? 0 : playerIcon.width + 10
                        implicitHeight: hidden ? 0 : playerIcon.height + 10

                        readonly property bool active: player.currentModelIndex === index
                            || (player.currentModelIndex === 0 && player.identity === identity)
                        onActiveChanged: if (active) playerRepeater.activeItem = this

                        Kirigami.Icon {
                            id: playerIcon
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.smallMedium
                            height: width
                            source: {
                                // Workaround for KDE 6.6.3 returning emblem-music-symbolic
                                // for all players: resolve icon from desktopEntry instead
                                var p = player.getPlayerAt(parent.index);
                                return (p && p.desktopEntry) ? p.desktopEntry : parent.iconName;
                            }
                            fallback: parent.iconName
                            color: Kirigami.Theme.textColor
                        }

                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: player.viewPlayer(parent.index)
                        }

                        PlasmaComponents3.ToolTip.text: identity
                        PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                        PlasmaComponents3.ToolTip.visible: hoverArea.containsMouse
                    }
                }
            }
        }

        Rectangle {
            id: thumbnailContainer
            visible: thumbnailVisible
            Layout.fillWidth: true
            Layout.margins: 10
            Layout.preferredHeight: thumbnailVisible ? width : 0
            color: 'transparent'

            PlasmaComponents3.ToolTip {
                id: raisePlayerTooltip
                anchors.centerIn: parent
                text: player.canRaise ? i18n("Bring player to the front") : i18n("This player can't be raised")
                visible: coverMouseArea.containsMouse
            }

            MouseArea {
                id: coverMouseArea
                anchors.fill: parent
                cursorShape: player.canRaise ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (player.canRaise) player.raise()
                }
                hoverEnabled: true
            }

            ImageWithPlaceholder {
                visible: !albumCoverBackground
                id: albumArtNormal
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit

                placeholderSource: albumPlaceholder
                imageSource: player.artUrl

                layer.enabled: root.fullAlbumCoverRounded && root.albumCoverRadius > 0
                layer.effect: OpacityMask {
					maskSource: Item {
						width: albumArtNormal.width
						height: albumArtNormal.height
						Rectangle {
							anchors.fill: parent
							radius: albumCoverRadius
						}
					}
				}
            }
        }

        SongAndArtistText {
            visible: songTextVisible && songTextAboveProgressBar
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 5
            textAlignment: songTextAlignment
            scrollingSpeed: plasmoid.configuration.fullViewTextScrollingSpeed
            title: player.title
            artists: player.artists
            album: player.album
            textFont: baseFont
            maxWidth: width
            titlePosition: plasmoid.configuration.fullTitlePosition
            artistsPosition: plasmoid.configuration.fullArtistsPosition
            albumPosition: plasmoid.configuration.fullAlbumPosition
        }

        TrackPositionSlider {
            visible: progressBarVisible
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            songPosition: player.songPosition
            songLength: player.songLength
            playing: player.playbackStatus === Mpris.PlaybackStatus.Playing
            enableChangePosition: player.canSeek
            onRequireChangePosition: (position) => {
                player.setPosition(position)
            }
            onRequireUpdatePosition: () => {
                player.updatePosition()
            }
        }

        SongAndArtistText {
            id: songText
            visible: songTextVisible && !songTextAboveProgressBar
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.topMargin: 5
            textAlignment: songTextAlignment
            scrollingSpeed: plasmoid.configuration.fullViewTextScrollingSpeed
            title: player.title
            artists: player.artists
            album: player.album
            textFont: baseFont
            maxWidth: songText.width
            titlePosition: plasmoid.configuration.fullTitlePosition
            artistsPosition: plasmoid.configuration.fullArtistsPosition
            albumPosition: plasmoid.configuration.fullAlbumPosition
            hideAlbumForSingles: plasmoid.configuration.fullHideAlbumForSingles
        }

        VolumeBar {
            visible: volumeControlVisible
            Layout.leftMargin: 40
            Layout.rightMargin: 40
            Layout.topMargin: 10
            volume: player.volume
            onSetVolume: (vol) => {
                player.setVolume(vol)
            }
            onVolumeUp: {
                player.changeVolume(volumeStep / 100, false)
            }
            onVolumeDown: {
                player.changeVolume(-volumeStep / 100, false)
            }
        }

        Item {
            visible: shuffleVisible || playbackControlsVisible || loopVisible
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.bottomMargin: 10
            Layout.fillWidth: playbackControlsFitWidth
            Layout.alignment: playbackControlsFitWidth ? 0 : Qt.AlignHCenter
            Layout.preferredWidth: playbackControlsFitWidth ? -1 : row.implicitWidth
            Layout.preferredHeight: row.implicitHeight
            RowLayout {
                id: row

                width: playbackControlsFitWidth ? parent.width : implicitWidth
                height: implicitHeight
                anchors.centerIn: parent

                CommandIcon {
                    visible: shuffleVisible
                    enabled: player.canChangeShuffle
                    Layout.alignment: Qt.AlignHCenter
                    size: Kirigami.Units.iconSizes.medium
                    source: "media-playlist-shuffle"
                    onClicked: player.setShuffle(player.shuffle === Mpris.ShuffleStatus.Off ? Mpris.ShuffleStatus.On : Mpris.ShuffleStatus.Off)
                    active: player.shuffle === Mpris.ShuffleStatus.On
                }

                CommandIcon {
                    visible: playbackControlsVisible
                    enabled: player.canGoPrevious
                    Layout.alignment: Qt.AlignHCenter
                    size: Kirigami.Units.iconSizes.medium
                    source: "media-skip-backward"
                    onClicked: player.previous()
                }

                CommandIcon {
                    visible: playbackControlsVisible
                    enabled: player.playbackStatus === Mpris.PlaybackStatus.Playing ? player.canPause : player.canPlay
                    Layout.alignment: Qt.AlignHCenter
                    size: Kirigami.Units.iconSizes.large
                    source: player.playbackStatus === Mpris.PlaybackStatus.Playing ? "media-playback-pause" : "media-playback-start"
                    onClicked: {
                        if (player.playbackStatus === Mpris.PlaybackStatus.Playing) {
                            player.playPause();
                        } else {
                            player.playExclusive();
                        }
                    }
                }

                CommandIcon {
                    visible: playbackControlsVisible
                    enabled: player.canGoNext
                    Layout.alignment: Qt.AlignHCenter
                    size: Kirigami.Units.iconSizes.medium
                    source: "media-skip-forward"
                    onClicked: player.next()
                }

                CommandIcon {
                    visible: loopVisible
                    enabled: player.canChangeLoopStatus
                    Layout.alignment: Qt.AlignHCenter
                    size: Kirigami.Units.iconSizes.medium
                    source: player.loopStatus === Mpris.LoopStatus.Track ? "media-playlist-repeat-song" : "media-playlist-repeat"
                    active: player.loopStatus != Mpris.LoopStatus.None
                    onClicked: () => {
                        let status = Mpris.LoopStatus.None;
                        if (player.loopStatus == Mpris.LoopStatus.None)
                            status = Mpris.LoopStatus.Track;
                        else if (player.loopStatus === Mpris.LoopStatus.Track)
                            status = Mpris.LoopStatus.Playlist;
                        player.setLoopStatus(status);
                    }
                }

            }

        }

    }
}
