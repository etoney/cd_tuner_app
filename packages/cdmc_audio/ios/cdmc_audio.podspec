Pod::Spec.new do |s|
  s.name             = 'cdmc_audio'
  s.version          = '0.1.0'
  s.summary          = 'Native audio engine for the Castle Danger tuner and metronome.'
  s.description      = 'Sample-accurate metronome that keeps playing on the lock screen, pitch detection and reference tones.'
  s.homepage         = 'https://castledangermusic.com'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Castle Danger Music Company' => 'hello@castledangermusic.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'
  s.swift_version    = '5.0'
  s.frameworks       = 'AVFoundation'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
