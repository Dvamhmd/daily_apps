// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

void _ensureJsHelpers() {
  if (!globalContext.hasProperty('saveFileWithCustomLocation'.toJS).toDart) {
    final scriptContent = '''
      window.saveFileWithCustomLocation = async function(base64Data, fileName) {
        if ('showSaveFilePicker' in window) {
          try {
            const handle = await window.showSaveFilePicker({
              suggestedName: fileName,
              types: [{
                description: 'JSON Backup File',
                accept: { 'application/json': ['.json'] }
              }]
            });
            const writable = await handle.createWritable();
            const byteCharacters = atob(base64Data);
            const byteArray = new Uint8Array(byteCharacters.length);
            for (let i = 0; i < byteCharacters.length; i++) {
              byteArray[i] = byteCharacters.charCodeAt(i);
            }
            await writable.write(byteArray);
            await writable.close();
            return handle.name || fileName;
          } catch (err) {
            if (err.name === 'AbortError') {
              return null;
            }
            console.error('Save error:', err);
            throw err;
          }
        } else {
          const link = document.createElement('a');
          link.href = 'data:application/json;base64,' + base64Data;
          link.download = fileName;
          document.body.appendChild(link);
          link.click();
          document.body.removeChild(link);
          return fileName;
        }
      };

      window.saveFileDirectDownload = function(base64Data, fileName) {
        const link = document.createElement('a');
        link.href = 'data:application/json;base64,' + base64Data;
        link.download = fileName;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        return fileName;
      };
    ''';
    final scriptEl = html.ScriptElement()..text = scriptContent;
    html.document.head?.append(scriptEl);
  }
}

Future<String?> saveFileWeb(
  Uint8List bytes,
  String fileName, {
  bool askLocation = false,
}) async {
  _ensureJsHelpers();
  final base64Str = base64Encode(bytes);

  if (askLocation) {
    try {
      final promise = globalContext.callMethod(
        'saveFileWithCustomLocation'.toJS,
        base64Str.toJS,
        fileName.toJS,
      );
      if (promise != null) {
        final jsPromise = promise as JSPromise<JSAny?>;
        final res = await jsPromise.toDart;
        if (res == null) {
          // Pengguna membatalkan dialog penyimpanan
          return null;
        }
        return (res as JSString).toDart;
      }
    } catch (_) {
      // Fallback
    }
  }

  // Direct download
  try {
    final res = globalContext.callMethod(
      'saveFileDirectDownload'.toJS,
      base64Str.toJS,
      fileName.toJS,
    );
    if (res != null) {
      return (res as JSString).toDart;
    }
    return fileName;
  } catch (_) {
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    return fileName;
  }
}
