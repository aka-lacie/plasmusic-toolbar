import QtQuick 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami

// inspired by https://stackoverflow.com/a/49031115/2568933
Item {
    id: root

    enum OverflowBehaviour {
        AlwaysScroll,
        ScrollOnMouseOver,
        StopScrollOnMouseOver
    }

    enum TruncateStyle {
        Elide,
        FadeOut,
        None
    }

    property int overflowBehaviour: ScrollingText.OverflowBehaviour.AlwaysScroll
    property int truncateStyle: ScrollingText.TruncateStyle.None

    property string text: ""
    readonly property string spacing: "     "
    readonly property string textAndSpacing: text + spacing
    property color textColor: Kirigami.Theme.textColor

    property int maxWidth: 200 * units.devicePixelRatio
    readonly property bool overflow: maxWidth <= textMetrics.width
    property int speed: 5;
    readonly property int duration: (25 * (11 - speed) + 25)* textAndSpacing.length;

    property bool scrollingEnabled: true
    property bool scrollResetOnPause: false
    property bool forcePauseScrolling: false
    readonly property bool overflowElides: truncateStyle === ScrollingText.TruncateStyle.Elide
    readonly property bool overflowFades: truncateStyle === ScrollingText.TruncateStyle.FadeOut

    readonly property bool pauseScrolling: {
        if (forcePauseScrolling) {
            return true;
        }
        if (overflowBehaviour === ScrollingText.OverflowBehaviour.AlwaysScroll) {
            return false;
        } else if (overflowBehaviour === ScrollingText.OverflowBehaviour.ScrollOnMouseOver) {
            return !mouse.hovered;
        } else if (overflowBehaviour === ScrollingText.OverflowBehaviour.StopScrollOnMouseOver) {
            return mouse.hovered;
        }
    }

    property alias font: label.font
    property int textAlignment: Qt.AlignHCenter

    implicitWidth: overflow ? maxWidth : textMetrics.width
    implicitHeight: Math.ceil(fontMetric.height)
    clip: overflow

    Layout.preferredHeight: implicitHeight

    FontMetrics {
        id: fontMetric
        font: label.font
    }
    Layout.fillWidth: true

    HoverHandler {
        id: mouse
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    TextMetrics {
        id: textMetrics
        font: label.font
        text: root.text
    }

    TextMetrics {
        id: elidedMetrics
        font: label.font
        text: root.text
        elide: Text.ElideRight
        elideWidth: root.maxWidth
    }

    // Re-establish color bindings on all labels. External tools like Panel
    // Colorizer walk the QML tree and do `child.color = value` on visible
    // labels, permanently breaking their declarative binding. This restores
    // bindings whenever the source color changes or a label becomes visible.
    function rebindColors() {
        staticLabel.color = Qt.binding(() => root.textColor)
        label.color = Qt.binding(() => root.textColor)
        scrollDuplicate.color = Qt.binding(() => root.textColor)
    }
    onTextColorChanged: rebindColors()

    // Static text for non-overflowing content, supports horizontal alignment.
    // Hidden when text overflows, where the scrolling text takes over instead.
    Text {
        id: staticLabel
        visible: !overflow
        anchors.fill: parent
        text: root.text
        color: root.textColor
        font: label.font
        wrapMode: Text.NoWrap
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: root.textAlignment
        onVisibleChanged: if (visible) color = Qt.binding(() => root.textColor)
    }

    Text {
        id: label
        visible: overflow
        text: overflow ? (root.overflowElides && !animationRunning ? elidedMetrics.elidedText : root.textAndSpacing) : root.text
        color: root.textColor
        wrapMode: Text.NoWrap
        anchors.verticalCenter: parent.verticalCenter
        property bool animationRunning: label.x !== 0 || (!animation.paused && animation.running)
        onVisibleChanged: if (visible) color = Qt.binding(() => root.textColor)

        NumberAnimation on x {
            id: animation
            running: root.overflow && root.scrollingEnabled
            paused: root.pauseScrolling && running
            from: 0
            to: -label.implicitWidth
            duration: root.duration
            loops: Animation.Infinite

            function reset() {
                label.x = 0;
                if (running) {
                    restart()
                }
                if (running && root.pauseScrolling) {
                    pause()
                }
            }

            onRunningChanged: () => {
                // When `running` becomes true the animation start regardless of the `pauseScrolling` value.
                // Manually pause the animation if the `pauseScrolling` value is true.
                if (running && root.pauseScrolling) {
                    pause()
                }
            }
            onToChanged: () => reset()
            onDurationChanged: () =>  reset()
            onPausedChanged: (paused) => {
                if (paused && scrollResetOnPause) label.x = 0
            }
        }

        Text {
            id: scrollDuplicate
            visible: root.overflow && label.animationRunning
            anchors.left: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: root.textColor
            font: label.font
            wrapMode: Text.NoWrap
            text: label.text
        }
    }
    layer.enabled: overflow && overflowFades && !label.animationRunning
    layer.effect: OpacityMask {
        invert: true
        maskSource: Item {
            width: root.width
            height: root.height
            LinearGradient {
                height: parent.height
                width: (textMetrics.width / textMetrics.text.length) * 2
                anchors.right: parent.right
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1.0,1.0,1.0,0.0) }
                    GradientStop { position: 0.5; color: Qt.rgba(1.0,1.0,1.0,0.5) }
                    GradientStop { position: 1.0; color: Qt.rgba(1.0,1.0,1.0,1.0) }
                    orientation: Gradient.Horizontal
                }
            }
        }
    }
}
