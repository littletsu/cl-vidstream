(ql:quickload '("dexador" "plump" "lquery" "lparallel" "jonathan" "ironclad" "cl-base64"))

(defvar *VIDSTREAM_HEADERS* '(("User-Agent" . "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0") 
                           ("Referer" . "https://gogoplay1.com/")
                           ("Accept" . "application/json, text/javascript, */*; q=0.01")
                           ("Accept-Language" . "en-US,en;q=0.5")
                           ("X-Requested-With" . "XMLHttpRequest")
                           ("Accept-Encoding" . "identity")
                           ("Cookie" . "tvshow=um3daqch58l3obl17kh4s8ie61; token=62dec0104b1fb")))

;;; Clone vidstream headers, but remove the cookie, encoding and change the referer
(defvar *ENCRYPTED_AJAX_HEADERS* (butlast (butlast (copy-list *VIDSTREAM_HEADERS*))))
(setf (cdr (nth 1 *ENCRYPTED_AJAX_HEADERS*)) "https://gogoplay1.com/streaming.php")

(defvar *NO_HEADERS* '())

;;; HTML
(defun getRequest(url &optional (headers *VIDSTREAM_HEADERS*) (force-binary nil))
  (dex:get url :headers headers :force-binary force-binary))

(defun getHtml(content)
  (lquery:$ (initialize content)))

(defun getHtmlRequest(url &optional (headers *VIDSTREAM_HEADERS*))
  (getHtml (getRequest url headers)))

;;; Searching
(defun getSearchAjaxContent(url)
  (getHtml (cdr (car (jonathan:parse (getRequest url) :as :alist)))))

(defun getSearchUrl(term) (format nil "https://gogoplay1.com/ajax-search.html?keyword=~A&id=-1" term))

(defun getSearchHtml(term) 
  (getSearchAjaxContent (getSearchUrl term)))

(defun getSearchResults(term)
  (let ((html (getSearchHtml term)))
  (lquery:$ html "a" (combine (attr :href) (text)))))

;;; Downloading
(defun getEpisodeUrl(searchResults i) 
  (format nil "https://gogoplay1.com~A" (car (aref searchResults i))))

(defun getStreamingUrl(episodeUrl) 
  (let ((html (getHtmlRequest episodeUrl)))
  (format nil "https:~A" (aref (lquery:$ html "iframe" (attr :src)) 0))))

(defun getStreamingHtml(url)
  (getHtmlRequest (getStreamingUrl url) *NO_HEADERS*))

(defun string-to-usb8-array(str)
  (map '(vector (unsigned-byte 8)) #'char-code str))

(defun usb8-array-to-string(str)
  (map 'string #'code-char str))

(defun getEncryptedParams(html)
  (cl-base64:base64-string-to-usb8-array (aref (lquery:$ html "script[data-name=\"episode\"]" (attr :data-value)) 0)))

(defun getEncryptedParamsKey(html)
  (string-to-usb8-array (subseq (aref (lquery:$ html "body" (attr :class)) 0) (length "container-"))))

(defun getDecryptionIv(html)
  (string-to-usb8-array (subseq (aref (lquery:$ html "div[class^=\"wrapper\"]" (attr :class)) 0) (length "wrapper container-"))))

(defun getVideoKey(html)
  (string-to-usb8-array (subseq (aref (lquery:$ html "div[class^=\"videocontent\"]" (attr :class)) 0) (length "videocontent videocontent-"))))

(defun makeParamsDecryptionCipher(html)
  (ironclad:make-cipher :aes :key (getEncryptedParamsKey html) :mode :cbc :initialization-vector (getDecryptionIv html) :padding :pkcs7))

(defun decryptParams(html)
  (usb8-array-to-string (ironclad:decrypt-message (makeParamsDecryptionCipher html) (getEncryptedParams html))))

(defun getVideoID(html)
  (string-to-usb8-array (aref (lquery:$ html "#id" (attr :value)) 0)))

(defun getEncryptedVideoId(html)
  (cl-base64:usb8-array-to-base64-string (ironclad:encrypt-message (makeParamsDecryptionCipher html) (getVideoId html))))

(defun getDecryptedAjaxUrl(html)
  (format nil "https://goload.io/encrypt-ajax.php?id=~A&alias=~A" (getEncryptedVideoId html) (decryptParams html)))

(defun makeSourcesDecryptionCipher(html)
  (ironclad:make-cipher :aes :key (getVideoKey html) :mode :cbc :initialization-vector (getDecryptionIv html) :padding :pkcs7))

(defun getEncryptedSourcesJson(html)
  (getRequest (getDecryptedAjaxUrl html) *ENCRYPTED_AJAX_HEADERS*))

(defun getEncryptedSources(html)
  (cl-base64:base64-string-to-usb8-array (cdr (car (jonathan:parse (getEncryptedSourcesJson html) :as :alist)))))

(defun getSources(url)
  (let ((html (getStreamingHtml url)))
  (jonathan:parse (usb8-array-to-string (ironclad:decrypt-message (makeSourcesDecryptionCipher html) (getEncryptedSources html))) :as :alist)))

(defun getMainSource(sources)
  (cdr (car (last (car (cdr (car (last sources))))))))
