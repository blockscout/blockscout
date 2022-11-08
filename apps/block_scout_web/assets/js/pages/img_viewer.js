import 'viewerjs/dist/viewer.min.css';
import Viewer from 'viewerjs';
const gallery = document.getElementById('gallery');
const viewer = new Viewer(gallery, {
    inline: false,
    toolbar: {
        zoomIn: 2,
        zoomOut: 4,
        oneToOne: 4,
        reset: 4,
        play: {
            show: 4,
            size: 'large',
        },
        rotateLeft: 4,
        rotateRight: 4,
        flipHorizontal: 4,
        flipVertical: 4,
    }
});
