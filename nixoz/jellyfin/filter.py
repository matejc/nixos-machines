import os
import subprocess

import jellyfin
from jellyfin.generated import (
    BaseItemDto,
    BaseItemKind,
    CollectionTypeOptions,
    CreatePlaylistDto,
    ItemFields,
    ItemsApi,
    MediaType,
    PlaylistsApi,
)

FRAME_SIZE = 64 * 64

api_key: str = os.getenv("JELLYFIN_API_KEY", "")
ffmpeg_path: str = os.getenv("JELLYFIN_FFMPEG", "ffmpeg")
dryrun: bool = os.getenv("JELLYFIN_DRYRUN", "") != ""
api = jellyfin.api(os.getenv("JELLYFIN_URL", "http://media.home.arpa"), api_key)
user = api.users.of(os.getenv("JELLYFIN_USER", ""))
items_api = ItemsApi(api.client)
playlists_api = PlaylistsApi(api.client)

def get_playlist(
    name: str,
    media_type: MediaType = MediaType.VIDEO,
) -> BaseItemDto:
    result = items_api.get_items(
        user_id=user.id,
        include_item_types=[BaseItemKind.PLAYLIST],
        recursive=True,
        search_term=name,
        limit=100,
    )

    for playlist in result.items or []:
        if playlist.name == name:
            return playlist

    created_playlist = playlists_api.create_playlist(
        create_playlist_dto=CreatePlaylistDto(
            name=name,
            user_id=user.id,
            media_type=media_type,
            ids=[],
        )
    )

    return created_playlist

def extract_frame(path: str, timestamp: float) -> bytes:
      if not os.path.isfile(path):
          raise FileNotFoundError(f"Media path does not exist or is not a file: {path!r}")
      if not os.access(path, os.R_OK):
          raise PermissionError(f"Media path is not readable: {path!r}")

      return subprocess.check_output(
          [
              ffmpeg_path,
              "-hide_banner",
              "-nostdin",
              "-loglevel", "error",
              "-ss", str(timestamp),
              "-i", path,
              "-frames:v", "1",
              "-vf", "scale=64:64,format=gray",
              "-f", "rawvideo",
              "-",
          ]
      )

def frames_mean_difference(path: str, duration: float) -> float:
    first = extract_frame(path, duration * 0.33)
    second = extract_frame(path, duration * 0.66)

    if len(first) != FRAME_SIZE or len(second) != FRAME_SIZE:
        return False

    mean_difference = sum(
        abs(a - b) for a, b in zip(first, second)
    ) / FRAME_SIZE

    # Pixel values range from 0 to 255.
    return mean_difference

library_api = api.generated.LibraryStructureApi(api.client)
libraries = library_api.get_virtual_folders()

music_video_libraries = [
    library
    for library in library_api.get_virtual_folders()
    if library.collection_type == CollectionTypeOptions.MUSICVIDEOS
]

for library in music_video_libraries:
    print(f"Checking library: {library.name} ...")

    library_items = (
        api.items.search
        .add("parent_id", library.item_id)
        .add("include_item_types", [BaseItemKind.MUSICVIDEO])
        .add("fields", [ItemFields.MEDIASOURCES])
        .recursive()
        .paginate(100)
        .all
    )

    playlist = get_playlist(library.name)
    playlist_items = playlists_api.get_playlist_items(
        playlist_id=playlist.id,
        user_id=user.id,
    )

    for item in library_items:
        duration_seconds = item.run_time_ticks // 10_000_000
        source = item.media_sources[0]
        size_mbytes = source.size // 1_000_000
        if duration_seconds >= 600 or any(
                playlist_item.id == item.id
                for playlist_item in playlist_items.items or []
            ):
            continue
        difference = frames_mean_difference(source.path, duration_seconds)
        if difference <= 5.0:
            continue
        print(f"Add '{item.name}' (length: {duration_seconds}s, size: {size_mbytes}MB, diff: {difference}) to playlist: '{playlist.name}' ...")
        if not dryrun:
            playlists_api.add_item_to_playlist(
                playlist_id=playlist.id,
                ids=[item.id],
                user_id=user.id,
            )
