//
//  ArtistListView.swift
//  Spotimy
//
//  Created by Andreas Garcia on 2023-07-20.
//

import SwiftUI
import Combine
import SpotifyWebAPI

struct ArtistListView: View {
    @EnvironmentObject var spotify: Spotify
    @State private var topArtists: [Artist] = []
    
    @State private var didRequestArtists = false
    @State private var isLoadingArtists = false
    @State private var artistsNotLoaded = false
    @State private var loadArtistsCancellable: AnyCancellable? = nil
    @State private var chosenTimeFrame: TimeFrame = TimeFrame.midTerm
    
    @State private var artistTopSongs: [String: URL] = [:]
    @State private var loadSongsCancellable = Set<AnyCancellable>()
    
    @StateObject private var audioManager = AudioManager()
    
    let mainColor = ColorModel.mainColor
    let textColor = ColorModel.textColor
    let accentColor = ColorModel.accentColor
    
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(mainColor)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(textColor)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(textColor)]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(accentColor)
    }
    
    var body: some View {
            Group {
                ZStack {
                    mainColor.ignoresSafeArea()
                    VStack {
                        Picker("", selection: $chosenTimeFrame) {
                            Text("Short Term").tag(TimeFrame.shortTerm)
                            Text("Mid Term").tag(TimeFrame.midTerm)
                            Text("Long Term").tag(TimeFrame.longTerm)
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, 20)
                        .padding(.leading, 20)
                        .padding(.trailing, 20)
                        .padding(.bottom, 5)
                        .onChange(of: chosenTimeFrame) { newTimeFrame in
                            let timeFrameString: String
                            switch newTimeFrame {
                            case .longTerm:
                                timeFrameString = "long_term"
                            case .midTerm:
                                timeFrameString = "medium_term"
                            case .shortTerm:
                                timeFrameString = "short_term"
                            }
                            getTopArtists(timeFrame: timeFrameString)
                        }
                        if topArtists.isEmpty {
                            if isLoadingArtists {
                                Spacer()
                                HStack {
                                    ProgressView()
                                        .padding()
                                }
                                Spacer()
                            }
                            else if artistsNotLoaded {
                                Text("Could Not Load Artists")
                                    .font(.title)
                            }
                            else {
                                Text("No Artists")
                                    .font(.title)
                            }
                        }
                        else {
                            ScrollView {
                                ForEach(topArtists, id: \.id) { artist in
                                    HStack(alignment: .top) {
                                        AsyncImage(url: artist.images?.largest?.url) { image in
                                            image
                                                .resizable()
                                                .frame(width: 50, height: 50)
                                                .aspectRatio(contentMode: .fit)
                                                .cornerRadius(10)
                                        } placeholder: {
                                            Image(systemName: "person.fill")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 50, height: 50)
                                                .foregroundColor(.gray)
                                                .cornerRadius(10)
                                        }
                                        Text(artist.name)
                                            .padding(.leading, 8)
                                            .padding(.top, 15)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .onAppear {
                                                getTopTracks(for: artist)
                                            }
                                        if let topTrack = artistTopSongs[artist.id!] {
                                            AudioPlayerView(audioURL: topTrack)
                                                .environmentObject(audioManager)
                                        } else {
                                            Image(systemName: "play")
                                                .resizable()
                                                .frame(width: 20, height: 20)
                                                .padding(.trailing, 10)
                                                .padding(.top, 15)
                                                .foregroundColor(accentColor)
                                        }
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                    .foregroundColor(textColor)
                }
        }
        .navigationTitle("My Artists")
        .onAppear {
            if !self.didRequestArtists {
                self.getTopArtists(timeFrame: "medium_term")
            }
        }
    }
    
    func getTopArtists(timeFrame: String) {
        self.didRequestArtists = true
        self.isLoadingArtists = true
        self.topArtists = []
        
        self.loadArtistsCancellable = spotify.spotifyAPI
            .currentUserTopArtists(TimeRange(rawValue: timeFrame), limit: 20)
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { completion in
                    self.isLoadingArtists = false
                    switch completion {
                        case .finished:
                            self.artistsNotLoaded = false
                        case .failure(let error):
                            self.artistsNotLoaded = true
                            print(error)
                    }
                },
                receiveValue: { topArtists in
                    let artists = topArtists.items
                        .filter { $0.id != nil }
                    self.topArtists.append(contentsOf: artists)
                })
    }
    
    func getTopTracks(for artist: Artist) {
        spotify.spotifyAPI.artistTopTracks("spotify:artist:" + artist.id!, country: "SE")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        print("Failed to fetch top tracks for artist \(artist.name): \(error)")
                    }
                },
                receiveValue: { tracks in
                    if let firstTrack = tracks.first {
                        artistTopSongs[artist.id!] = firstTrack.previewURL
                    } else {
                        artistTopSongs[artist.id!] = nil
                    }
                }
            )
            .store(in: &loadSongsCancellable)
    }
}


struct ArtistListView_Previews: PreviewProvider {
    static var spotify = Spotify()
    
    static var previews: some View {
        ArtistListView()
            .environmentObject(spotify)
    }
}
