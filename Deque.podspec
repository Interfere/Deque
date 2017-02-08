Pod::Spec.new do |s|
  s.name = 'Deque'
  s.version = '0.0.1'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.summary = 'Deque is an implementation of double-ended queue container'
  s.homepage = 'https://github.com/Interfere/Deque'
  s.author = { 'Alexey Komnin' => 'interfere.work@gmail.com' }
  s.source = { :git => 'https://github.com/Interfere/Deque.git', :tag => s.version.to_s }
  s.source_files = 'Deque.swift', 'RingBuffer.swift'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
end
