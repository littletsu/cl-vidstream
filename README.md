# cl-vidstream
Common Lisp functions to search and get m3u8 videos from vidstreaming<br><br>
Loading in SBCL:
```
sbcl --load ./cl-vidstream/cl-vidstream.cl
```

Main functionality example:<br>
```cl
(getMainSource (getSources (getEpisodeUrl (getSearchResults "serial experiments lain") 0)))
> "https://(...)/ep.13.1645681949.m3u8"
```
