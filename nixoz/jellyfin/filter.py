import os

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

api_key: str = os.getenv("JELLYFIN_API_KEY", "")
dryrun: bool = os.getenv("JELLYFIN_DRYRUN", "") != ""
api = jellyfin.api(os.getenv("JELLYFIN_URL", "http://media.local"), api_key)
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
        length_seconds = item.run_time_ticks // 10_000_000
        size_mbytes = item.media_sources[0].size // 1_000_000
        if length_seconds < 600 and size_mbytes > 20 and not any(
                playlist_item.id == item.id
                for playlist_item in playlist_items.items or []
            ):
                print(f"Add '{item.name}' (lenght: {length_seconds}s, size: {size_mbytes}MB) to playlist: '{playlist.name}' ...")
                if not dryrun:
                    playlists_api.add_item_to_playlist(
                        playlist_id=playlist.id,
                        ids=[item.id],
                        user_id=user.id,
                    )
