import 'artist_ref.dart';

class Artist {
  final String id;
  final String name;
  final String? coverArt;
  final int? albumCount;
  final String? artistImageUrl;
  final bool isLocal;
  final List<ArtistRef>? artistParticipants;
  final int? nbFans;

  Artist({
    required this.id,
    required this.name,
    this.coverArt,
    this.albumCount,
    this.artistImageUrl,
    this.isLocal = false,
    this.artistParticipants,
    this.nbFans,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown Artist',
      coverArt: json['coverArt']?.toString(),
      albumCount: json['albumCount'] as int?,
      artistImageUrl: json['artistImageUrl']?.toString(),
      artistParticipants: ArtistRef.parseList(json['artists']),
      nbFans: (json['nb_fan'] ?? json['nbFans'] ?? json['fansCount']) as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'coverArt': coverArt,
      'albumCount': albumCount,
      'artistImageUrl': artistImageUrl,
      if (artistParticipants != null)
        'artists':
            artistParticipants!.map((artist) => artist.toJson()).toList(),
      if (nbFans != null) 'nbFans': nbFans,
    };
  }
}
