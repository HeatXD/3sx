// Drag-and-drop AFS handler for 3SX WASM build.
// Bundled via --pre-js in the Emscripten link step.
//
// Flow:
//   1. User drags the SF33RD.AFS file onto the canvas.
//   2. JS reads the file into an ArrayBuffer and writes it to MEMFS at /SF33RD.AFS.
//   3. JS calls Module._Resources_OnAFSDropped() to notify the C side.
//   4. C's MAIN_PHASE_COPYING_RESOURCES sees the flag and transitions to initialized.

var Module = Module || {};

Module['onRuntimeInitialized'] = (function(prev) {
    return function() {
        if (prev) prev();

        var canvas = document.getElementById('canvas');
        if (!canvas) return;

        // Overlay shown until the AFS file is dropped
        var overlay = document.createElement('div');
        overlay.style.cssText = [
            'position:absolute',
            'inset:0',
            'display:flex',
            'flex-direction:column',
            'align-items:center',
            'justify-content:center',
            'background:rgba(0,0,0,0.75)',
            'color:#fff',
            'font:bold 18px/1.4 monospace',
            'pointer-events:none',
            'text-align:center',
            'z-index:10',
            'transition:background 0.15s',
        ].join(';');
        overlay.innerHTML = 'Drop <code>SF33RD.AFS</code> here to start';

        // The canvas is inside a container — wrap if needed
        var container = canvas.parentElement;
        container.style.position = 'relative';
        container.appendChild(overlay);

        canvas.style.transition = 'outline 0.1s';

        canvas.addEventListener('dragover', function(e) {
            e.preventDefault();
            overlay.style.background = 'rgba(255,255,255,0.15)';
            canvas.style.outline = '3px solid #fff';
        });

        canvas.addEventListener('dragleave', function() {
            overlay.style.background = 'rgba(0,0,0,0.75)';
            canvas.style.outline = '';
        });

        canvas.addEventListener('drop', async function(e) {
            e.preventDefault();
            overlay.style.background = 'rgba(0,0,0,0.75)';
            canvas.style.outline = '';

            var file = e.dataTransfer.files[0];
            if (!file) return;

            overlay.innerHTML = 'Loading\u2026';

            var buf = await file.arrayBuffer();
            FS.writeFile('/SF33RD.AFS', new Uint8Array(buf));
            overlay.remove();
            Module._Resources_OnAFSDropped();
        });
    };
}(Module['onRuntimeInitialized']));
